# -*- coding: utf-8 -*-
"""
Created on Sun Oct 11 22:16:22 2020

@author: Jagdish Chhabria
"""
# Import libraries
import pandas as pd
import numpy as np
import plotly.graph_objs as go

import dash
import dash_core_components as dcc
import dash_html_components as html
from dash.dependencies import Input, Output

# Initialize dataframes
trees= pd.DataFrame()
trees_count= pd.DataFrame()
trees_health= pd.DataFrame()

 # Initialize variables to read in data
step=1000
total_rows=5000

# Use SoQL to download the NY Trees data
for x in range(0, total_rows, step):
    soql_url = ('https://data.cityofnewyork.us/resource/nwxe-4ae8.json?$limit=1000&$offset='+str(x)+'&$select=boroname,borocode,spc_common,steward,health,count(tree_id)'+'&$group=boroname,borocode,spc_common,steward,health').replace(' ', '%20')
    soql_trees = pd.read_json(soql_url)
    trees = trees.append(soql_trees)

# Data manipulation for question 1- Create health proportion for each tree type and borough
trees.dropna(inplace=True,axis=0)
trees.reset_index(drop=True, inplace=True)
trees.sort_values(['boroname','borocode','spc_common','steward','health'], ascending=True, inplace=True)
trees['count_tree_id']=trees['count_tree_id'].astype(int)

trees_count = trees.groupby(['borocode','spc_common'])['count_tree_id'].sum()
trees_count = trees_count.reset_index(drop=False)

trees_health = trees.groupby(['borocode','spc_common','health'])['count_tree_id'].sum()
trees_health = trees_health.reset_index(drop=False)

trees_health_count = pd.merge(trees_count, trees_health, on=['borocode','spc_common'])
trees_health_count['proportion']=round(trees_health_count['count_tree_id_y']/trees_health_count['count_tree_id_x'],2)

trees_health_count.loc[trees_health_count['borocode']==1,'boroname']='Manhattan'
trees_health_count.loc[trees_health_count['borocode']==2,'boroname']='Bronx'
trees_health_count.loc[trees_health_count['borocode']==3,'boroname']='Brooklyn'
trees_health_count.loc[trees_health_count['borocode']==4,'boroname']='Queens'
trees_health_count.loc[trees_health_count['borocode']==5,'boroname']='Staten Island'

types = np.sort(trees_health_count.spc_common.unique())

# Data manipulation for question 2 - Create weighted average health score for each stewarding level
health_dict = {'Poor':1, 'Fair':2, 'Good':3}
trees['health_score'] = trees['health'].map(health_dict)
steward_dict = {'3or4':3, '4orMore':4, 'None':1, '1or2':2}
trees['steward_level'] = trees['steward'].map(steward_dict)

trees_steward = trees.groupby(['boroname','borocode','spc_common','steward'])['count_tree_id'].sum()
trees_steward = trees_steward.reset_index(drop=False)
trees_combined = pd.merge(trees, trees_steward, on=['boroname','borocode','spc_common','steward'])
trees_combined['wted_score']=(trees_combined['count_tree_id_x']*trees_combined['health_score'])/trees_combined['count_tree_id_y']
trees_combined_health = trees_combined.groupby(['boroname','borocode','spc_common','steward_level'])['wted_score'].sum().reset_index(drop=False)

# Prepare for Dash deployment
external_stylesheets = ['https://codepen.io/chriddyp/pen/bWLwgP.css']

app = dash.Dash(__name__, external_stylesheets=external_stylesheets)
server=app.server
server.secret_key = os.environ.get('secret_key', 'secret')

app.layout = html.Div([
    html.H4('Select Tree'),

    dcc.Dropdown(
        id='tree',
        options=[{'label': i, 'value': i} for i in types],
        value="'Schubert' Chokecherry",
        style={'height': 'auto', 'width': '250px'}
    ),

    dcc.Graph(id='graph-tree-ratio'),
    dcc.Graph(id='graph-tree-health')

], style={'columnCount': 1})

#Display Stacked Bar Graph for Question 1
@app.callback(
    Output('graph-tree-ratio', 'figure'),
    [Input('tree','value')])

def update_figure1(tree_type):
    trees_ratio = trees_health_count[trees_health_count.spc_common == tree_type]
    
    poor = trees_ratio[trees_ratio.health == 'Poor']
    good = trees_ratio[trees_ratio.health == 'Good']
    fair = trees_ratio[trees_ratio.health == 'Fair']

    fig = go.Figure(go.Bar(x=poor['boroname'], y=poor['proportion'], name='Poor', text=poor['proportion'],textposition='auto'))
    fig.add_trace(go.Bar(x=fair['boroname'], y=fair['proportion'], name='Fair', text=fair['proportion'],textposition='auto'))
    fig.add_trace(go.Bar(x=good['boroname'], y=good['proportion'], name='Good',text=good['proportion'],textposition='auto'))

    fig.update_layout(barmode='stack', xaxis=dict(title = 'Borough'), 
    yaxis={'title':'Proportion of Tree Health in Borough'},
    margin={'l':40,'b':40,'t':10,'r':10}, 
    legend=dict(x=-.1, y=1.2)
    )
    return fig

# Display Scatter plot for question 2
@app.callback(
    Output('graph-tree-health', 'figure'),
    [Input('tree','value')])

def update_figure2(tree_type):
    trees_combined_health_one = trees_combined_health[trees_combined_health.spc_common == tree_type]
   
    figure = go.Figure(data=go.Scatter(x=trees_combined_health_one['steward_level'],
    y=trees_combined_health_one['wted_score'],
    mode='markers',
    marker=dict(color=trees_combined_health_one['borocode']),
    #showlegend=True,
    hovertext=trees_combined_health_one['boroname']
    ))

    figure.update_layout(title='Tree Health by Stewarding Level')
    figure.update_layout(
     xaxis=dict(tickvals = [1,2,3,4], ticktext = ['None', '1or2', '3or4', '4orMore'], title='Stewarding Level'),
     yaxis=dict(tickvals = [0,1,2,3,4], title = 'Tree Health Score',range=(0, 4)),
     margin={'l':40,'b':40,'t':30,'r':20},
     legend=dict(x=1, y=1.2)
    )
    return figure

if __name__ == '__main__':
    app.run_server(debug=True)
    
   #app.run(debug=True, port=int(os.environ.get("PORT", 5000)), host='0.0.0.0')
