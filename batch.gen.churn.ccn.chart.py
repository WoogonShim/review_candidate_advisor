#!/usr/bin/python
# * coding:utf-8 *

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

def get_last_dirname(aPath):
	last_dirname = os.path.basename(os.path.normpath(aPath))
	return last_dirname

def get_churn_complexity(df, type, prefix):
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
			label = "{0}/{1}::{2}".format(repo, row['filename'], row['function name'])
			churn_complexity.append(
				{'value': eval(value), 'label': label})
	return churn_complexity

# pygal 을 사용하여 차트 생성 - http://pygal.org/
import pygal  # First import pygal
from pygal import Config

class XYConfig(Config):
	stroke=False
	show_legend=False
	title_font_size=20
	fill = True
#	x_scale = 5
#	y_scale = 10
	tooltip_font_size = 12
	x_title = 'churn (# of commits)'
	y_title = 'complexity'

def build_chart(churn_complexity, name, data_type, output_filename):
	chart = pygal.XY(XYConfig()) 
	total = '{0:,}'.format(len(churn_complexity))
	chart.title = '"{0}" churn vs complexity ({1}) - total {2} items'.format(name, data_type, total)
	if len(churn_complexity) == 1:
		churn_complexity.append({'value': (0,0), 'label': 'origin'})
	chart.add('values', churn_complexity)  # Add some values
	fileName, fileExtension = os.path.splitext(output_filename)
	if fileExtension.lower() == "png":
		chart.render_to_png(output_filename)
	else:
		chart.render_to_file(output_filename) 
	return

import getopt, sys, os

verbose = False
output_filename = 'churn_complexity_chart(all files).svg'
result_csv_filename = "file_churn_complexity(all files).csv"

def usage():
    usage = """
  Read csv file(s) and generate churn-complexity chart for project's whole files

    -h --help                 Prints this
    -o --output               Output filename

  *) Before using this script, you should execute 'run.batch.at' script
    """
    print usage

def main():
	global input_filename, output_filename, verbose

	try:
		opts, args = getopt.gnu_getopt(sys.argv[1:], 'ho:v', ['help', 
															   'output=', 
		                                                       'verbose',
		                                                      ])
	except getopt.GetoptError, err:
		print str(err)
		usage()
		sys.exit(2)

	for opt, arg in opts:
		if opt in ('-h', '--help'):
			usage()
			sys.exit()
		elif opt in ('-o', '--output'):
			output_filename = arg
		elif opt in ('-v', '--verbose'):
			verbose = True


if __name__ == "__main__":
    main()

def get_all_csv_files():
	git_repo_list = []
	csv_file_list = []
	with open('git-repo-list', 'r') as fp:
	    for line in fp:
	    	target_dir = line.replace('\n', '')
	    	git_repo_list.append(target_dir)
	    	csv_file_list.append('./churn-complexity-output' + 
	    		target_dir + '/file_churn_complexity.csv')
	return csv_file_list, git_repo_list

def get_common_prefix(git_repo_list):
	common_prefix = os.path.commonprefix(git_repo_list)
	return common_prefix

def get_csv_path_prefix(csv_filepath):
	prefix = ''

	if csv_filepath.find('churn-complexity-output/') >= 0:
		prefix = '/' + os.path.relpath(
							os.path.normpath(os.path.dirname(csv_filepath)), 
							"churn-complexity-output")
	return prefix

def generate_project_level_chart(git_repo_list, csv_file_list, title, data_type, output_filename):
	chart = pygal.XY(XYConfig()) 
	total = 0
	
	common_prefix = get_common_prefix(git_repo_list)
	for index, csv_filepath in enumerate(csv_file_list):
		df        = read_csv_file(csv_filepath)
		repo_name = get_last_dirname(git_repo_list[index])
		churn_complexity = get_churn_complexity(df, data_type, common_prefix)
		data_count= len(churn_complexity)

		if data_count == 1:
			churn_complexity.append({'value': (0,0), 'label': 'origin'})
		chart.add(repo_name, churn_complexity)  # Add some values
		total += data_count
		
	total = '{0:,}'.format(data_count)
	chart.title = '"{0}" churn vs complexity ({1}) - total {2} items'.format(title, data_type, total)
	fileName, fileExtension = os.path.splitext(output_filename)
	if fileExtension.lower() == "png":
		chart.render_to_png(output_filename)
	else:
		chart.render_to_file(output_filename) 

def generate_all_repos_chart(git_repo_list, csv_file_list):
	common_prefix = get_common_prefix(git_repo_list)
	for index, csv_filepath in enumerate(csv_file_list):
		df        = read_csv_file(csv_filepath)
		data_type = get_type(df)
		repo_name = get_last_dirname(git_repo_list[index])
		churn_complexity = get_churn_complexity(df, data_type, common_prefix)
		output_filename  = os.path.join(os.path.normpath(os.path.dirname(csv_filepath)), 'churn-complexity-chart.svg')
		if len(churn_complexity) > 0: build_chart(churn_complexity, repo_name, data_type, output_filename)

def cumulate_df_from_all_csv_files(csv_file_list):
	cumulative_df = pd.DataFrame()
	for csv_filepath in csv_file_list:
		df = read_csv_file(csv_filepath)
		df['repo_name'] = get_csv_path_prefix(csv_filepath)
		cumulative_df = cumulative_df.append(df)
	return cumulative_df

def write_all_files(cumulative_df, result_csv_filename):
	df = cumulative_df.sort(
		['commits', 'file complexity', 'max complexity', 'filename'], ascending=[False, False, False, True])
	df.to_csv(result_csv_filename,
				cols=['repo_name', 'filename', 'commits', 'file complexity', '# of function', 'avg complexity', 'max function name', 'max complexity', 'authors', 'committers'],
				header=True,index=False)

print "================================================================================"
print "  Generating churn-complexity chart (for project's whole files)"
print "================================================================================"
print "1/8) Read input file ('git-repo-list')",
csv_file_list, git_repo_list = get_all_csv_files()
print " ... Done"
print "  => total {0} repositories".format(len(csv_file_list))
print "2/8) Get project base directory path",
common_prefix = get_common_prefix(git_repo_list)
print " ... Done"
print "  => '", common_prefix, "'"
print "3/8) Reading and collecting all 'file_churn_complexity.csv' files",
cumulative_df = cumulate_df_from_all_csv_files(csv_file_list)
print " ... Done"
print "4/8) Determining csv file type",
data_type = get_type(cumulative_df)
print " ... Done ('", data_type, "')"
print "5/8) Retrieving churn-complexity data from all csv files",
churn_complexity = get_churn_complexity(cumulative_df, data_type, common_prefix)
total_files = '{0:,}'.format(len(churn_complexity))
print " ... Done"
print "  => Total {0} files".format(total_files)
print "6/8) Generating churn-complexity chart",
title = get_last_dirname(common_prefix)
#build_chart(churn_complexity, title, data_type, output_filename)
generate_project_level_chart(git_repo_list, csv_file_list, title, data_type, output_filename)
print " ... Done"
print "  => See result at '", output_filename, "'"
print "7/8) Generating csv file for project's whole files",
write_all_files(cumulative_df, result_csv_filename)
print " ... Done"
print "  => See also '", result_csv_filename, "'"
print "8/8) Generating churn-complexity chart for each git",
generate_all_repos_chart(git_repo_list, csv_file_list)
print " ... Done"
