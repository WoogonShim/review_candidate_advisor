#!/usr/bin/python
# * coding:utf-8 *

import pygal  # First import pygal
from pygal import Config

class XYConfig(Config):
	stroke=False
	show_legend=False
	title_font_size=20
	fill = True
	tooltip_font_size = 12
	x_title = 'churn (# of commits)'
	y_title = 'complexity'

chart = pygal.XY(XYConfig()) 
chart.title = 'test'
churn_complexity = [{'value': (0,0), 'label': 'origin'}]
churn_complexity.append({'value': (7, 38), 'label': '/src/snapshot-boot.c'})
chart.add('values', churn_complexity)  # Add some values
chart.render_to_file("test.svg") 
