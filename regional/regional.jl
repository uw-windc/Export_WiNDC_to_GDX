using DataFrames
using WiNDCNational

using WiNDCRegional
using WiNDCRegional.WiNDCContainer
using JLD2
using Dates


# ===============
# Build the Data
# ===============

data_dir = raw"C:\Users\Mitch\Documents\WiNDC\windc_raw_data\2024\regional"

state_table_full = create_state_table(data_dir)

state_table = State(
    table(state_table_full, :year => 2024),
    sets(state_table_full),
    elements(state_table_full)
)

@save "regional/state_table_2024.jld2" state_table


@save "regional/state_table.jld2" state_table=state_table_full


# ===============
# Load the Data
# ===============

@load "regional/state_table.jld2" state_table


# ===============
# Explore the Data
# ===============



# ===============
# Export to GDX
# ===============

#sets(state_table) |>
#    x -> subset(x, :domain => ByRow(!=(:parameter))) |>
#    x -> sort(x, :domain)


all_sets = Dict(
    :commodity                => "com",
    :margin                   => "mar",
    :sector                   => "sec",
    :state                    => "state",
    :year                     => "yr",
)

#sets(state_table) |>
#    x -> subset(x, :domain => ByRow(==(:parameter))) |>
#    x -> sort(x, :name)


all_parameters = Dict(
    :Capital_Demand           => Dict(:domain => (col = :sector, region = :state, year = :year)),            
    :Duty                     => Dict(:domain => (row = :commodity, region = :state, year = :year)),  
    :Export                   => Dict(:domain => (row = :commodity, region = :state, year = :year)),             
    :Government_Final_Demand  => Dict(:domain => (row = :commodity, region = :state, year = :year)),                     
    :Household_Supply         => Dict(:domain => (row = :commodity, region = :state, year = :year)),              
    :Import                   => Dict(:domain => (row = :commodity, region = :state, year = :year)),    
    :Intermediate_Demand      => Dict(:domain => (row = :commodity, col = :sector, region = :state, year = :year)),                 
    :Intermediate_Supply      => Dict(:domain => (row = :commodity, col = :sector, region = :state, year = :year)),                 
    :Investment_Final_Demand  => Dict(:domain => (row = :commodity, region = :state, year = :year)),                     
    :Labor_Demand             => Dict(:domain => (col = :sector, region = :state, year = :year)),          
    :Local_Demand             => Dict(:domain => (row = :commodity, region = :state, year = :year)),          
    :Local_Margin_Supply      => Dict(:domain => (row = :commodity, col = :margin, region = :state, year = :year)),                 
    :Margin_Demand            => Dict(:domain => (row = :commodity, col = :margin, region = :state, year = :year)),           
    :Margin_Supply            => Dict(:domain => (row = :commodity, col = :margin, region = :state, year = :year)),           
    :National_Demand          => Dict(:domain => (row = :commodity, region = :state, year = :year)),             
    :National_Margin_Supply   => Dict(:domain => (row = :commodity, col = :margin, region = :state, year = :year)),                                 
    :Output_Tax               => Dict(:domain => (col = :sector, region = :state, year = :year)),        
    :Personal_Consumption     => Dict(:domain => (row = :commodity, region = :state, year = :year)),                  
    :Reexport                 => Dict(:domain => (row = :commodity, region = :state, year = :year)),      
    :Tax                      => Dict(:domain => (row = :commodity, region = :state, year = :year)),      
)

G = GDXFile("state.gdx")

G[:metadata] = GDXSet("metadata", "Metadata about creation of the GDX file", ["*"], 
    DataFrame([
        (name = "version", element_text = "4.2.0"),
        (name = "data_source", element_text = "WiNDCRegional.jl"),
        (name = "creation_time", element_text = string(Dates.now())),
        (name = "Contact", element_text = "mphillipson@wisc.edu"),
    ])
)

for (s, gams_name) in all_sets
    description = sets(state_table, s) |> x -> x[1, :description]
    df = elements(state_table, s) |> x -> select(x, :name, :description => :element_text)
    
    if s in [:state, :destination]
        df = transform(df, 
            :name => ByRow(x -> replace(x, " "=> "_")) => :name
        )
    end

    G[gams_name] = GDXSet(gams_name, description, ["*"], df)
end


for (parm, parameter) in all_parameters
    description = sets(state_table, parm) |> x -> x[1, :description]
    dom = [all_sets[s] for (_,s) in pairs(parameter[:domain])]

    df = table(state_table, parm; normalize = :Use) |>
        x -> select(x, [pairs(parameter[:domain])..., :value => :value]) |>
        x -> transform(x, 
            :state => ByRow(x -> replace(x, " "=> "_")) => :state
            )
    G[parm] = GDXParameter(String(parm), description, dom, df)
end

G

write_gdx("regional/regional.gdx", G)







# ==============
# Testing
# ==============

df = WiNDCRegional.balance_of_payments(state_table)

df |>
    x -> subset(x,
        :year => ByRow(==(1998)),
        :row => ByRow(==(Symbol("111CA")))
    )

table(state_table, 
    :Value_Added,
    :Household_Supply,
    :Output_Tax,
    :Tax,
    :Duty;
    normalize = :Supply
)