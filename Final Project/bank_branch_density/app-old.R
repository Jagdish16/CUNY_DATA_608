#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
#
# Find out more about building applications with Shiny here:
#
#    http://shiny.rstudio.com/
# Name of Application: bank_branch_density

library(shiny)
library(dplyr)
library(ggplot2)
library(kableExtra)
library(usmap)
library(ggmap)
library(readr)
library(stringr)
library(tidyverse)
library(maps)

# Load map data for USA
usa_map<-map_data("usa")
states<-map_data("state")

# Load the Census population data from 2010 to 2019
census_population_data<-read_csv('census_states_population_2019.csv')

# Convert from a wide to a long format
pop_hist<-census_population_data%>%gather(Year,Population,4:13)

# Add a new column for population in ten thousands
pop_hist$Population_10000<-round(pop_hist$Population/10000,0)

# Remove rows related to regions and columns for Region Number and State Number
pop_hist<-pop_hist[!pop_hist$Region %in% c('Northeast Region','Midwest Region', 'South Region','West Region'),]

# Remove columns not required
pop_hist<-subset(pop_hist,select=-c(Region_Number,State_Number))

# Load data for regional branches and USA as a whole
usa_branches<-read_csv("usa_bank_data.csv")
region_branches<-read_csv("states_bank_data.csv")

# Filter for years 2010 to 2019
region_branches<-subset(region_branches,Year>=2010)
region_branches<-subset(region_branches,Year<2020)

# Merge branch data and population for states for years 2010 and later
branches_per_cap<-merge(y=region_branches,x=pop_hist,by=c("Year","Region"),all.x = TRUE)

# Calculate branches per 10000 people for the states
branches_per_cap$Branches_Per_Capita<-round(branches_per_cap$Number_of_Branches/branches_per_cap$Population_10000,2)

# Rename the region column in the states data and change case from lower to camel
states<-states%>%rename("Region"="region")
states$Region<-str_to_title(states$Region,locale="en")

state_per_cap_branch<-dplyr::left_join(states, branches_per_cap, by='Region')

# Define UI for the application
ui <- fluidPage(

    # Application title
    titlePanel("State-wise Bank Branch Density Per Capita (10000 people)"),
    
    # Sidebar with a selection for Year
    sidebarLayout(
        sidebarPanel(
            selectInput('year',"Select Year",state_per_cap_branch$Year%>%unique,selected=NULL,multiple=FALSE,selectize=TRUE),
        ),

        # Show a chloropeth map for selected year
        mainPanel(
            girafeOutput("heatMap",width="110%",height=400)
        )
    )
)

# Define server logic required to draw the plot
server<-shinyServer(function(input,output,session)
#server <- function(input, output) 
{

    # Create a new dataset by filtering branches by state only
    state_pcb<-reactive({state_per_cap_branch%>%filter(Year==input$year)})
    
    output$heatMap<-renderGirafe({
    p2<-ggplot(data=state_pcb())+geom_polygon_interactive(aes(x=long,y=lat,fill=Branches_Per_Capita,group=group,tooltip=paste(Region,":",Branches_Per_Capita)),data_id=state_pcb()$Region,color="white")+theme_classic()+xlab("Longitude")+ylab("Latitude")+labs(title=paste("State-wise Bank Branch Density Per 10000 people in ",input$year))+labs(fill="Branch Density")+scale_fill_gradient(low="white",high="#CB454A")+theme(legend.position="right",legend.background=element_rect(size=2,linetype='solid'),legend.text = element_text(size=6),legend.title=element_text(size=8),legend.box.margin = margin(0, 0, 0, 0, "cm"))
        
    girafe(code=print(p2),width_svg=9,height_svg=6,options=list(opts_sizing(rescale=FALSE)))
    })
}
)

# Run the application 
shinyApp(ui = ui, server = server)
