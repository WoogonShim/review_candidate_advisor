#!/usr/bin/python

# 알아야 할 것들
# 1. 파라미터로 대상 파일경로 넘겨주기
# 2. 함수 어떻게 만드나
# 3. 함수에 dictoionary 넘겨주기
# 4. 파일(csv)에서 읽어오기 => dictionary 에 넣기 (file complexity, max complexity, avg complexity)
# 5. dictionary 정렬하기 (commits, complexity)
# 6. 만들어진 dictionary 차트로 만들기

# pygal 을 사용하여 차트 생성 - http://pygal.org/
import pygal  # First import pygal
bar_chart = pygal.Bar()  # Then create a bar graph object
bar_chart.add('Fibonacci', [0, 1, 1, 2, 3, 5, 8, 13, 21, 34, 55])  # Add some values
#bar_chart.render_to_file('bar_chart.svg') 
bar_chart.render_to_png('bar_chart.png') 