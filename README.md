# r-ramm

R wrapper for the RAMM API (https://api.ramm.com/v1/).

For a Python version with improved API and functionality see [pyramm](https://github.com/captif-nz/pyramm).

## Dependencies
* devtools
* urltools
* data.table
* kv - install using `devtools::install_github('decisionpatterns/kv')`

## Installation
* Install above dependencies
* Run `devtools::install_github('captif-nz/r-ramm')`

## Usage
Create Ramm object: `ramm <- ramm::Ramm()`
### Login
`ramm$login('username', 'password')`

### List tables
`ramm$get_table_names()`

### List columns
`ramm$get_column_names(tablename)`

### Get data
`ramm$get_data(tablename)`

It is possible to specify a set of filters using the *filters* parameter.

*filters* must be a list containing one or more entries like `list(columnName='<column_name>', operator='<operator>', value='<value>')`, where *column_name*, *operator* and *value* should be replaced with appropriate values.

Valid operators include:
* EqualTo
* GreaterThan
* LessThan
* In
* *possibly others*

#### Get data examples
`roadnames <- ramm$get_data('roadnames', filters=list(list(columnName='road_region', operator='EqualTo', value=1)))`

`roadnames <- ramm$get_data('roadnames', filters=list(list(columnName='road_region', operator='GreaterThan', value=0), list(columnName='road_region', operator='LessThan', value=3)))`

`roadnames <- ramm$get_data('roadnames', filters=list(list(columnName='road_region', operator='In', value='1,2')))`

`hsd_rutting <- ramm$get_data('hsd_rutting', filters=list(list(columnName='road_id', operator='EqualTo', value=615),list(columnName='latest', operator='EqualTo', value='L')))`

## Issues
Please submit an issue if you come across a bug.

## License
MIT
