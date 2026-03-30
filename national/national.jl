using WiNDCNational
using DataFrames
using JLD2
import OrderedCollections: OrderedDict
using GDXInterface
using Dates
using JSON

# ===============
# Build the Data
# ===============

# summary_raw = build_us_table() # replace :summary with :detailed for the detailed tables
# summary,_ = calibrate(summary_raw)
# 
# @save "national/national.jld2" summary

# =============
# Load the Data
# =============


@load "national/national.jld2" summary



# ===============
# Export to GDX
# ===============

all_sets = Dict(
    :sector                   => "sec",
    :year                     => "yr",
    :commodity                => "com",
    :investment_final_demand  => "ifd",
    :margin                   => "mar",
    :government_final_demand  => "gfd"
)


all_parameters = Dict(
    :Capital_Demand =>             Dict(:domain => OrderedDict(:col => :sector, :year => :year)),
    :Duty =>                       Dict(:domain => OrderedDict(:row => :commodity, :year => :year)),
    :Export =>                     Dict(:domain => OrderedDict(:row => :commodity, :year => :year)),
    #:Final_Demand =>               Dict(:domain => OrderedDict(:year => :year)),
    :Government_Final_Demand =>    Dict(:domain => OrderedDict(:row => :commodity, :col => :government_final_demand, :year => :year)),
    :Household_Supply =>           Dict(:domain => OrderedDict(:row => :commodity, :year => :year)),
    :Import =>                     Dict(:domain => OrderedDict(:row => :commodity, :year => :year)),
    :Intermediate_Demand =>        Dict(:domain => OrderedDict(:row => :commodity, :col => :sector, :year => :year)),
    :Intermediate_Supply =>        Dict(:domain => OrderedDict(:row => :commodity, :col => :sector, :year => :year)),
    :Investment_Final_Demand =>    Dict(:domain => OrderedDict(:row => :commodity, :col => :investment_final_demand, :year => :year)),
    :Labor_Demand =>               Dict(:domain => OrderedDict(:col => :sector, :year => :year)),
    :Margin_Demand =>              Dict(:domain => OrderedDict(:row => :commodity, :col => :margin, :year => :year)),
    :Margin_Supply =>              Dict(:domain => OrderedDict(:row => :commodity, :col => :margin, :year => :year)),
    #:Other_Final_Demand =>         Dict(:domain => OrderedDict(:row => :commodity, :year => :year)),
    :Output_Tax =>                 Dict(:domain => OrderedDict(:col => :sector, :year => :year)),
    :Personal_Consumption =>       Dict(:domain => OrderedDict(:row => :commodity, :year => :year)),
    :Sector_Subsidy =>             Dict(:domain => OrderedDict(:col => :sector, :year => :year)),
    :Subsidy =>                    Dict(:domain => OrderedDict(:row => :commodity, :year => :year)),
    #:Supply =>                     Dict(:domain => OrderedDict(:year => :year)),
    :Tax =>                        Dict(:domain => OrderedDict(:row => :commodity, :year => :year)),
    #:Use =>                        Dict(:domain => OrderedDict(:year => :year)),
    #:Value_Added =>                Dict(:domain => OrderedDict(:year => :year)),
)




G = GDXFile("national.gdx")

G[:metadata] = GDXSet("metadata", "Metadata about creation of the GDX file", ["*"], 
    DataFrame([
        (name = "version", element_text = "4.2.0"),
        (name = "data_source", element_text = "WiNDCNational.jl"),
        (name = "creation_time", element_text = string(Dates.now())),
        (name = "Contact", element_text = "mphillipson@wisc.edu"),
    ])
)

for (s, gams_name) in all_sets
    description = sets(summary, s) |> x -> x[1, :description]
    df = elements(summary, s) |> x -> select(x, :name, :description => :element_text)
    
    G[gams_name] = GDXSet(gams_name, description, ["*"], df)
end

for (parm, parameter) in all_parameters
    description = sets(summary, parm) |> x -> x[1, :description]
    dom = [all_sets[s] for (_,s) in parameter[:domain]]
    df = table(summary, parm; normalize = :Use) |> x -> select(x, [parameter[:domain]..., :value => :value])

    G[parm] = GDXParameter(String(parm), description, dom, df)
end



G

write_gdx("national/national.gdx", G)


