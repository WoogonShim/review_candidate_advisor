#!/usr/bin/python
# * coding:utf-8 *

# 알아야 할 것들
# 1. 파라미터로 대상 파일경로 넘겨주기
# 2. 함수 어떻게 만드나
# 3. 함수에 dictoionary 넘겨주기
# 4. 파일(csv)에서 읽어오기 => dictionary 에 넣기 (file complexity, max complexity, avg complexity)
# 5. dictionary 정렬하기 (commits, complexity)
# 6. 만들어진 dictionary 차트로 만들기

# pygal 을 사용하여 차트 생성 - http://pygal.org/
import pygal  # First import pygal
from pygal import Config

class XYConfig(Config):
	stroke=False
	show_legend=False
	title_font_size=20
	#human_readable = True
	fill = True
	# x_scale = 5
	# y_scale = 10
	tooltip_font_size = 14
	x_title = 'churn (# of commits)'
	y_title = 'complexity'

chart = pygal.XY(XYConfig())  # Then create a bar graph object

chart.title = 'churn vs complexity'
chart.add('values', [(0, 1), (1, 2), (3, 5), (8, 13), (2, 21), (34, 55)])  # Add some values
chart.render_to_file('chart.svg') 
#chart.render_to_png('chart.png') 