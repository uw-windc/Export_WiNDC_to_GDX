using WiNDCHousehold
using WiNDCHousehold.WiNDCContainer
using DataFrames
using JLD2
import OrderedCollections: OrderedDict
using GDXInterface

using JSON
using Dates

# ===============
# Build the Data
# ===============
#state_table, HH_Raw_Data = WiNDCHousehold.household_raw_data("household/household.yaml")
#
#HH = WiNDCHousehold.build_household_table(
#    state_table,
#    HH_Raw_Data;
#)
#
#@save "household/household.jld2" HH



# ===============
# Load the Data
# ===============

@load "household/household.jld2" HH



# ===============
# Explore the Data
# ===============

df = WiNDCHousehold.regional_national_supply(HH)

df |> 
    x -> sort(x, :value) |>
    x -> subset(x,
        :region => ByRow(==("Alaska")),
        :row => By
    )







# ===============
# Export to GDX
# ===============

sets(HH) |>
    x -> subset(x, :domain => ByRow(!=(:parameter))) |>
    x -> sort(x, :domain)

all_sets = Dict(
    :commodity =>                "com",
    :destination =>              "dest",
    :household =>                "h",
    :margin =>                   "mar",
    :sector =>                   "sec",
    :state =>                    "state",
    :transfer_payment =>         "trn",
    :year =>                     "yr",
    #:average_labor_tax =>        "",
    #:capital_demand =>           "",
    #:capital_tax =>              "",
    #:duty =>                     "",
    #:export =>                   "",
    #:fica =>                     "",
    #:government_final_demand =>  "",
    #:import =>                   "",
    #:interest =>                 "",
    #:investment_final_demand =>  "ifd",
    #:labor_demand =>             "",
    #:local_demand =>             "",
    #:marginal_labor_tax =>       "",
    #:national_demand =>          "",
    #:output_tax =>               "",
    #:reexport =>                 "",
    #:savings =>                  "",
    #:tax =>                      "",
    #:trade =>                    "",
    #:transport =>                "",
)


sets(HH) |>
    x -> subset(x, :domain => ByRow(==(:parameter))) |>
    x -> sort(x, :domain)

all_parameters = Dict(
    :Average_Labor_Tax         => Dict(:domain => OrderedDict(:col => :household, :region => :state)),
    :Capital_Demand            => Dict(:domain => OrderedDict(:col => :sector, :region => :state)),
    :Capital_Tax               => Dict(:domain => OrderedDict(:col => :sector, :region => :state)),
    :Duty                      => Dict(:domain => OrderedDict(:row => :commodity, :region => :state)),
    :Export                    => Dict(:domain => OrderedDict(:row => :commodity, :region => :state)),
    :FICA_Tax                  => Dict(:domain => OrderedDict(:col => :household, :region => :state)),
    :Government_Final_Demand   => Dict(:domain => OrderedDict(:row => :commodity, :region => :state)),
    :Household_Interest        => Dict(:domain => OrderedDict(:col => :household, :region => :state)),
    :Household_Supply          => Dict(:domain => OrderedDict(:row => :commodity, :region => :state)),
    :Import                    => Dict(:domain => OrderedDict(:row => :commodity, :region => :state)),
    :Intermediate_Demand       => Dict(:domain => OrderedDict(:row => :commodity, :col => :sector, :region => :state)),
    :Intermediate_Supply       => Dict(:domain => OrderedDict(:row => :commodity, :col => :sector, :region => :state)),
    :Investment_Final_Demand   => Dict(:domain => OrderedDict(:row => :commodity, :region => :state)),
    :Labor_Demand              => Dict(:domain => OrderedDict(:col => :sector, :region => :state)),
    :Labor_Endowment           => Dict(:domain => OrderedDict(:row => :destination, :col => :household, :region => :state)),
    :Local_Demand              => Dict(:domain => OrderedDict(:row => :commodity, :region => :state)),
    :Local_Margin_Supply       => Dict(:domain => OrderedDict(:row => :commodity, :col => :margin, :region => :state)),
    :Margin_Demand             => Dict(:domain => OrderedDict(:row => :commodity, :col => :margin, :region => :state)),
    :Marginal_Labor_Tax        => Dict(:domain => OrderedDict(:col => :household, :region => :state)),
    :National_Demand           => Dict(:domain => OrderedDict(:row => :commodity, :region => :state)),
    :National_Margin_Supply    => Dict(:domain => OrderedDict(:row => :commodity, :col => :margin, :region => :state)),
    :Output_Tax                => Dict(:domain => OrderedDict(:col => :sector, :region => :state)),
    :Personal_Consumption      => Dict(:domain => OrderedDict(:row => :commodity, :col => :household, :region => :state)),
    :Reexport                  => Dict(:domain => OrderedDict(:row => :commodity, :region => :state)),
    :Savings                   => Dict(:domain => OrderedDict(:col => :household, :region => :state)),
    :Tax                       => Dict(:domain => OrderedDict(:row => :commodity, :region => :state)),
    :Transfer_Payment          => Dict(:domain => OrderedDict(:row => :transfer_payment, :col => :household, :region => :state)),
    #:Final_Demand              => Dict(:domain => OrderedDict()),
    #:Margin_Supply             => Dict(:domain => OrderedDict()),
    #:Other_Final_Demand        => Dict(:domain => OrderedDict()),
    #:Supply                    => Dict(:domain => OrderedDict()),
    #:Use                       => Dict(:domain => OrderedDict()),
    #:Value_Added               => Dict(:domain => OrderedDict()),
)



G = GDXFile("household.gdx")

G[:metadata] = GDXSet("metadata", "Metadata about creation of the GDX file", ["*"], 
    DataFrame([
        (name = "version", element_text = "4.2.0"),
        (name = "data_source", element_text = "WiNDCHousehold.jl"),
        (name = "creation_time", element_text = string(Dates.now())),
        (name = "Contact", element_text = "mphillipson@wisc.edu"),
    ])
)

for (s, gams_name) in all_sets
    description = sets(HH, s) |> x -> x[1, :description]
    df = elements(HH, s) |> x -> select(x, :name, :description => :element_text)
    
    if s in [:state, :destination]
        df = transform(df, 
            :name => ByRow(x -> replace(x, " "=> "_")) => :name
        )
    end

    G[gams_name] = GDXSet(gams_name, description, ["*"], df)
end

for (parm, parameter) in all_parameters
    description = sets(HH, parm) |> x -> x[1, :description]
    dom = [all_sets[s] for (_,s) in parameter[:domain]]

    df = table(HH, parm; normalize = :Use) |>
        x -> select(x, [parameter[:domain]..., :value => :value]) |>
        x -> transform(x, 
            :state => ByRow(x -> replace(x, " "=> "_")) => :state)

        if get(parameter[:domain], :row, :miss) == :destination
            df = df |> x -> transform(x, 
                :destination => ByRow(x -> replace(x, " "=> "_")) => :destination)
        end

    G[parm] = GDXParameter(String(parm), description, dom, df)
end


G

write_gdx("household/household.gdx", G)














md""" 
Others:

1. netport
2. regional_national_supply
3. regional_local_supply
4. total_supply
5. absorption
6. labor_supply
7. leisure_demand
8. leisure_consumption_elasticity
9. invest
10. government_deficit
"""

out_dir = "household_data_raw"

if !isdir(out_dir)
    mkdir(out_dir)
    mkdir(joinpath(out_dir, "set"))
    mkdir(joinpath(out_dir, "parameter"))
end


begin
    used_sets = []
    data_description = Dict()
    data_description["sets"] = Dict()
    data_description["parameters"] = Dict()

    for (name, parameter) in all_parameters
        df = table(HH, name; normalize = :Use) |>
            x -> select(x, [parameter[:domain]..., :value => :value]) |>
            x -> transform(x, 
                :state => ByRow(x -> replace(x, " "=> "_")) => :state)

            if get(parameter[:domain], :row, :miss) == :destination
                df = df |> x -> transform(x, 
                    :destination => ByRow(x -> replace(x, " "=> "_")) => :destination)
            end

        CSV.write(joinpath(out_dir, "parameter", string(name, ".csv")), df)

        description = sets(HH, name) |>
            x -> x[1, :description]

        data_description["parameters"][string(name)] = Dict(
            "description" => description,
            "domain" => [string(k) for k in values(parameter[:domain])],
        )

        used_sets = append!(used_sets, collect(values(parameter[:domain]))) |> unique

    end

    for S in used_sets
        df = elements(HH, S) |>
            x -> select(x, [:name, :description])

        if S in [:state, :destination]
            df = transform(df, 
                :name => ByRow(x -> replace(x, " "=> "_")) => :name)
        end

        CSV.write(joinpath(out_dir, "set", string(S, ".csv")), df)

        description = sets(HH, S) |>
            x -> x[1, :description]

        data_description["sets"][string(S)] = Dict(
            "description" => description,
            "alias" => all_sets[Symbol(S)],
        )
    end

    file = joinpath(out_dir, "data_description.json")
    open(file, "w") do f
        JSON.print(f, data_description)
    end

end


