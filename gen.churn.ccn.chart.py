#!/usr/bin/python
# * coding:utf-8 *

# pandas 를 이용하여 csv 파일 읽어들이기
import pandas as pd

def read_csv_file(filepath):
	df = pd.read_csv(filepath,
			delimiter=',\s*',
			header=0,
			encoding='utf-8')
	df = df.sort(
		['commits', 'file complexity', 'filename', 'repo_name'], ascending=[False, False, False, True])
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

def get_churn_complexity(df, type, common_prefix):
	repo_churn_complexity = {}
	repo = ''

	for row_index, row in df.iterrows():
		if 'repo_name' in df.columns: 
			repo = os.path.relpath(row['repo_name'], common_prefix)

		if type == 'file':
			value = "({0},{1})".format(row['commits'], row['file complexity'])
			label = "{0}/{1}".format(repo, row['filename'])
			if not repo in repo_churn_complexity.keys():
				repo_churn_complexity[repo] = []
			repo_churn_complexity[repo].append(
				{'value': eval(value), 'label': label})
		else:
			value = "({0},{1})".format(row['commits'], row['function complexity'])
			label = "{0}/{1}::{2}".format(repo, row['filename'], row['function name'])
			if not repo in repo_churn_complexity.keys():
				repo_churn_complexity[repo] = []
			repo_churn_complexity['values'].append(
				{'value': eval(value), 'label': label})

	return len(df.index), repo_churn_complexity

# pygal 을 사용하여 차트 생성 - http://pygal.org/
import pygal  # First import pygal
from pygal import Config

class XYConfig(Config):
	stroke=False
	show_legend=True
	legend_font_size=10
	legend_at_bottom=True
	title_font_size=20
	fill = True
	x_scale = 5
	y_scale = 10
	tooltip_font_size = 12
	x_title = 'churn (# of commits)'
	y_title = 'complexity'

def build_chart(repo_churn_complexity, name, total, data_type, output_filename):
	chart = pygal.XY(XYConfig())
	chart.title = '"{0}" churn vs complexity ({1}) - total {2} items'.format(name, data_type, total)
	for repo_name, churn_complexity in repo_churn_complexity.iteritems():
		if len(churn_complexity) == 1:
			churn_complexity.append({'value': (0,0), 'label': 'origin'})
		chart.add(repo_name, churn_complexity)  # Add some values

	fileName, fileExtension = os.path.splitext(output_filename)
	if fileExtension.lower() == "png":
		chart.render_to_png(output_filename)
	else:
		chart.render_to_file(output_filename) 

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
    main()

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
path_prefix = get_path_prefix(input_filename)
total, repo_churn_complexity = get_churn_complexity(df, data_type, path_prefix)
print " ... Done"
print "4/4) Generating churn-complexity chart",
title = get_last_dirname(input_filename)
build_chart(repo_churn_complexity, title, total, data_type, output_filename)
print " ... Done ('", output_filename, "')"
