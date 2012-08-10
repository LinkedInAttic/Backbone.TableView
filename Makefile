all: coffee minify

coffee:
	coffee -cb backbone.tableview.coffee

minify: coffee
	closure-compiler backbone.tableview.js > backbone.tableview.min.js
