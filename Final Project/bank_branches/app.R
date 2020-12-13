#
# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
# Find out more about building applications with Shiny here:
#    http://shiny.rstudio.com/
#
# Name of application = bank_branches

library(shiny)
library(dplyr)
library(ggplot2)
library(rsconnect)
library(plotly)
library(kableExtra)
library(readr)
library(leaflet)
library(tidyverse)
library(maps)
#rsconnect::deployApp('~/ShinyApps/banks')

# Load the Bank Branches data for different years
all2020<-read_csv('ALL_2020.csv')

# Make a list of columns of interest
cols<-c('ASSET', 'CHARTER', 'CITYBR', 'CNTRYNA', 'DEPDOM', 'DEPSUM', 'DEPSUMBR', 'NAMEBR', 'NAMEFULL', 'REGAGNT', 'RSSDID', 'SIMS_LATITUDE', 'SIMS_LONGITUDE', 'SPECDESC', 'SPECGRP', 'STALPBR', 'STNAMEBR', 'UNINUMBR', 'YEAR', 'ZIPBR')

# Filter the data frame to select only the columns of interest
all2020<-all2020[ ,which((names(all2020) %in% cols)==TRUE)]

# Rename the columns to more intuitive names
all2020<-all2020%>%rename(state_code=STALPBR, region=STNAMEBR, total_assets=ASSET, city=CITYBR, domestic_deposits=DEPDOM, total_deposits=DEPSUM, branch_deposits=DEPSUMBR, branch=NAMEBR, bank_name=NAMEFULL,regulator=REGAGNT, specialization=SPECDESC, branch_id=RSSDID,zipcode=ZIPBR, location_id=UNINUMBR, spec_grp=SPECGRP, branch_lat=SIMS_LATITUDE, branch_lon=SIMS_LONGITUDE)

# Convert the region column to lower case to enable merging
all2020$region<-tolower(all2020$region)

# Create a new dataframe with top banks by branch count
shortlist<-all2020%>%group_by(bank_name)%>%summarise(n=n())%>%arrange(desc(n))%>%top_n(5)

# Create a new dataframe for just the top banks by branch count
top5_2020<-all2020[all2020$bank_name %in% shortlist$bank_name,]

# Create a dataframe with the bank short names
short<-read.table(file="bank_short_names.txt",header=TRUE,sep="|")

# Merge the dataframes so that the bank short name is part of the top bank dataset
top5_2020<-merge(top5_2020,short,by='bank_name')

# Filter for Bank of America branches
bankam_branches_2020<-top5_2020%>%filter(bank=="Bank of America")

# Create icon based on Bank of America logo
bankamIcon<-icons("bankam.png",iconWidth=8,iconHeight=8)

# Define UI for application
ui <- fluidPage(
    
    # Application title
    titlePanel("Bank of America Branches By State for 2020"),
    
    # Sidebar with a selection for State 
    sidebarLayout(
        sidebarPanel(
            #selectInput('bank',"Select Bank",top15$bank%>%unique,selected=NULL, multiple=FALSE,selectize=TRUE),
            selectInput('state',"Select State",bankam_branches_2020$state_code%>%unique,selected=NULL,multiple=FALSE,selectize=TRUE),
        ),
        # Show a spatial density map for selected bank and state
        mainPanel(
            leafletOutput("densityMap",width="100%",height=400)
        )
    )
)

server<-shinyServer(function(input,output,session)
#server <- function(input, output) 
{
    # Create a new dataset by filtering branches by state only
    bank_state<-reactive({bankam_branches_2020%>%filter(state_code==input$state)})
    
    output$densityMap<-renderLeaflet({
        leaflet()%>%addProviderTiles("CartoDB.Positron")%>%addMarkers(data=bank_state(),lng=~branch_lon,lat=~branch_lat,icon=bankamIcon,label=~branch,popup=~paste("Deposits = $",branch_deposits))
    })
}
)

# Run the application 
shinyApp(ui = ui, server = server)

