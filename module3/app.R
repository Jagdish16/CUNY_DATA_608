# Jagdish Chhabria - Module 3 - DATA 608

# This is a Shiny web application. You can run the application by clicking
# the 'Run App' button above.
# Find out more about building applications with Shiny here:
#    http://shiny.rstudio.com/


library(shiny)
library(dplyr)
library(ggplot2)
library(rsconnect)
library(plotly)
#rsconnect::deployApp('~/ShinyApps/mortality')

# Question 1: As a researcher, you frequently compare mortality rates from particular causes across different States. You need a visualization that will let you see (for 2010 only) the crude mortality rate, across all States, from one cause (for example, Neoplasms, which are effectively cancers). Create a visualization that allows you to rank States by crude mortality for each cause of death.

#Load the CDC dataset and filter for the 2010 year

cdc<-read.csv('cleaned-cdc-mortality-1999-2010.csv')
cdc.2010<-cdc%>%filter(Year==2010)

# Define UI for application
ui <- fluidPage(

    # Application title
    titlePanel("Crude Mortality By State and Cause"),

    # Sidebar with a selectinput for cause of death 
    sidebarLayout(
        sidebarPanel(
            selectInput('cause', "Select Cause", cdc$ICD.Chapter%>%unique,selected = NULL, multiple = FALSE, selectize = TRUE)
        ),
        # Show a horizontal barplot of the mortality rate by state for the selected cause
        mainPanel(
           plotOutput("barPlot")
        )
    )
)

server<-shinyServer(function(input, output,session)
#server <- function(input, output) 
    {
    # Define server logic required to draw a bar chart based on user selection
    
    cdc.2010.cause<-reactive(cdc.2010%>%filter(ICD.Chapter==input$cause))
    
    output$barPlot<-renderPlot({
        ggplot(cdc.2010.cause())+geom_bar(aes(reorder(State,Crude.Rate),Crude.Rate,fill=State),stat='identity')+coord_flip()+geom_text(aes(x=State,y=Crude.Rate,label=Crude.Rate),size=2, hjust=0, vjust=-0.2,position=position_dodge(.9))+ggtitle("Crude Mortality by State for 2010")+theme(axis.text.x = element_text(size=8, angle = 90, hjust = 1), axis.text.y = element_text(size=6), axis.title=element_text(size=14,face="bold")) + labs(title = paste('Crude Mortality by State for ',input$cause), x = 'State', y='Crude Mortality')
    })
})

# Run the application 
shinyApp(ui = ui, server = server)


# Question 2: Often you are asked whether particular States are improving their mortality rates (per cause) faster than, or slower than, the national average. Create a visualization that lets your clients see this for themselves for one cause of death at the time. Keep in mind that the national average should be weighted by the national population.

# Create new data sets to calculate the national average mortality date for each cause of death
cdc.states<-cdc%>%select(ICD.Chapter,Year,Crude.Rate,State)

cdc.nation<-cdc%>%group_by(ICD.Chapter,Year)%>%summarize(Crude.Rate=(sum(Deaths)*100000/sum(Population)))%>%mutate(State='USA')

cdc.nation$State<-as.factor(cdc.nation$State)

cdc.combined<-dplyr::bind_rows(cdc.states,cdc.nation)

# Define UI for application
ui <- fluidPage(
    
    # Application title
    titlePanel("Trend in Mortality By State and Cause versus National Average"),
    
    # Sidebar with a selectinput for cause of death 
    sidebarLayout(
        sidebarPanel(
            selectInput('cause', "Select Cause", cdc.combined$ICD.Chapter%>%unique,selected = NULL, multiple = FALSE, selectize = TRUE),
            
            selectInput('state', "Select State", cdc.combined$State%>%unique,selected = NULL, multiple = FALSE, selectize = TRUE)
        ),
        # Show a line plot comparing the national average mortality rate with that of the selected state and the selected cause
        mainPanel(
            plotOutput("linePlot")
        )
    )
)

server<-shinyServer(function(input, output,session)
    #server <- function(input, output) 
{
    # Define server logic required to draw a line plot based on user selection
    
    cdc.cause.state<-reactive(cdc.combined%>%filter(ICD.Chapter==input$cause & (State=='USA'|State==input$state)))
    
    output$linePlot<-renderPlot({
        ggplot(data=cdc.cause.state())+geom_line(aes(x=Year,y=Crude.Rate,color=State))+ggtitle("Trend in Mortality by State and National Average")+labs(title = paste('Trend in Mortality in ',input$state,' for ',input$cause), x = 'Year', y='Crude Mortality')
    })
})

# Run the application 
shinyApp(ui = ui, server = server)


