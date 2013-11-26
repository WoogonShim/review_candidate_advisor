#!/usr/bin/python
# * coding:utf-8 *

# 알아야 할 것들
# 1. 파라미터로 대상 파일경로 넘겨주기
# 2. 함수 어떻게 만드나
# 3. 함수에 dictoionary 넘겨주기
# 4. 파일(csv)에서 읽어오기 => dictionary 에 넣기 (file complexity, max complexity, avg complexity)
# 5. dictionary 정렬하기 (commits, complexity)
# 6. 만들어진 dictionary 차트로 만들기

# pandas 를 이용하여 csv 파일 읽어들이기
import pandas as pd

def read_csv_file(filepath):
	df = pd.read_csv(filepath,
			delimiter=',\s*',
			header=0,
			encoding='utf-8')
	return df

def get_type(df):
	if 'function name' in df.columns: 
		return 'function'
	else:
		return 'file'

def get_last_dirname(input_filename):
	last_dirname = os.path.basename(os.path.normpath(os.path.join(input_filename, os.pardir)))
	return last_dirname

def get_path_prefix(input_filename):
	prefix = ''

	if input_filename.find('churn-complexity-output/') >= 0:
		prefix = '/' + os.path.relpath(
							os.path.normpath(os.path.dirname(input_filename)), 
							"churn-complexity-output")
	return prefix

def get_churn_complexity(df, type, input_filename):
	prefix = get_path_prefix(input_filename)
	churn_complexity = []
	repo = ''

	for row_index, row in df.iterrows():
		if 'repo_name' in df.columns: repo = os.path.relpath(row['repo_name'], prefix)

		if type == 'file':
			value = "({0},{1})".format(row['commits'], row['file complexity'])
			label = "{0}/{1}".format(repo, row['filename'])
			churn_complexity.append(
				{'value': eval(value), 'label': label})
		else:
			value = "({0},{1})".format(row['commits'], row['function complexity'])
			label = "{0}/{1}/{2}".format(repo, row['filename'], row['function name'])
			churn_complexity.append(
				{'value': eval(value), 'label': label})

	# print df
	# print "===========================\n"
	# df.sort(['commits', 'avg complexity'], ascending=[False, False]);
	# print df
	return churn_complexity

# pygal 을 사용하여 차트 생성 - http://pygal.org/
import pygal  # First import pygal
from pygal import Config
#from pygal.style import NeonStyle

class XYConfig(Config):
	stroke=False
	show_legend=False
	title_font_size=20
	#style=NeonStyle
	#human_readable = True
	fill = True
	x_scale = 5
	y_scale = 10
	tooltip_font_size = 12
	x_title = 'churn (# of commits)'
	y_title = 'complexity'

def build_chart(churn_complexity, name, data_type, output_filename):
	chart = pygal.XY(XYConfig())  # Then create a bar graph object
	chart.title = '"{0}" churn vs complexity ({1})'.format(name, data_type)
#	print churn_complexity
	chart.add('values', churn_complexity)  # Add some values
	fileName, fileExtension = os.path.splitext(output_filename)
	if fileExtension.lower() == "png":
		chart.render_to_png(output_filename)
	else:
		chart.render_to_file(output_filename) 

# -csvfile=...path.csv -outfile=
import getopt, sys, os

verbose = False
input_filename  = 'top_20_risk_files(max).csv'
output_filename = 'churn_complexity_chart.svg'

def usage():
    usage = """
  Read csv file(s) and generate churn-complexity chart

    -h --help                 Prints this
    -i --input                Path of csv file
    -o --output               Output filename

  *) Before using this script, you should execute 'run.batch.at' script
    """
    print usage

def main():
	global input_filename, output_filename, verbose

	try:
		opts, args = getopt.gnu_getopt(sys.argv[1:], 'hi:o:v', ['help', 'input=',
															   'output=', 
		                                                       'verbose',
		                                                      ])
	except getopt.GetoptError, err:
		print str(err)
		usage()
		sys.exit(2)

	if len(opts) == 0:
		usage()
		sys.exit(2)

	for opt, arg in opts:
		if opt in ('-h', '--help'):
			usage()
			sys.exit()
		elif opt in ('-i', '--input'):
			input_filename = arg
		elif opt in ('-o', '--output'):
			output_filename = arg
		elif opt in ('-v', '--verbose'):
			verbose = True


if __name__ == "__main__":
    main() # [1:] slices off the first argument which is the name of the program

print "================================================================================"
print "  Generating churn-complexity chart\n"
print "  from '{0}'".format(input_filename)
print "================================================================================"
print "1/4) Read input csv file ('", os.path.basename(input_filename),"')",
df = read_csv_file(input_filename)
print " ... Done"
print "2/4) Determining csv file type",
data_type = get_type(df)
print " ... Done ('", data_type, "')"
print "3/4) Retrieving churn-complexity data from csv file",
churn_complexity = get_churn_complexity(df, data_type, input_filename)
print " ... Done"
print "4/4) Generating churn-complexity chart",
name = get_last_dirname(input_filename)
build_chart(churn_complexity, name, data_type, output_filename)
print " ... Done ('", output_filename, "')"
