
library(httr)
library(urltools)
library(kv)
library(xml2)
library(jsonlite)

#' Ramm class
#'
#' @description Class for interacting with the RAMM API. Avaliable methods
#'  include:
#'  login(username, password)
#'  get_table_names()
#'  get_column_names(table_name, get_geometry=FALSE)
#'  get_data(table_name, get_geometry=FALSE, filters=list(), chunck_size=5000,
#'  column_names=c())
#'
#' @examples
#' ramm <- Ramm()
Ramm = setRefClass(
  "Ramm",
  field = list(
    url = "character",
    database = "character",
    http_header = "list"
  ),
  method = list(
    initialize = function (
      ...,
      url = "https://apps.ramm.co.nz/RammApi6.1/v1",
      database = "SH New Zealand",
      http_header = list(
        "Content-type" = "application/json",
        "referer" = "https://test.com"
      )
    ) {
      callSuper(url = url, database = database, http_header = http_header)
    }
  )
)

#' Set authorisation key.
#' @name Ramm_set_auth_key
#' @param params list("userName"=..., "password"=..., "database"=...)
NULL
Ramm$methods(
  set_auth_key = function (params) {
    uu <- paste(url, "/authenticate/login?", sep = "")

    response <- POST(
      append_params(uu, params),
      add_headers(.headers = sapply(http_header, paste0))
      )

    if (response$status_code == 200) {
      auth_key <- gsub(
        "[\"]",
        "",
        content(response, "text", encoding = "ISO-8859-1")
      )

      http_header$Authorization <<- paste("Bearer", auth_key)

      print("Successfully logged in.")

    } else {
      print(content(response, "text", encoding = "ISO-8859-1"))
      stop("Login failed, try again.")
    }
  }
)
#' Log in to RAMM API
#' @name Ramm_login
#' @param username RAMM username
#' @param password RAMM password
NULL
Ramm$methods(
  login = function (username, password) {
    params <- list(
      "userName" = username,
      "password" = password,
      "database" = database)
    set_auth_key(params)
  }
)

#' HTTP request to RAMM API.
#' @name Ramm_request
#' @param cmd command URL from https://api.ramm.com/v1/
#' @param method HTTP request method ("GET" or "POST")
#' @param body HTTP request body
#' @return HTTP response object
NULL
Ramm$methods(
  request = function (cmd, method="GET", body=NULL) {
    if (method == "GET") {
      response <- GET(
        paste(url, cmd, sep=""),
        add_headers(.headers = sapply(http_header, paste0))
      )
    } else if (method == "POST") {
      response <- POST(
        paste(url, cmd, sep=""),
        add_headers(.headers = sapply(http_header, paste0)),
        body = body
      )
    } else {
      print("Use GET or POST method.")
    }
  response
  }
)

#' List of tables in the RAMM database.
#' @name Ramm_get_table_names
#' @return List of RAMM table names
NULL
Ramm$methods(
  get_table_names = function () {
    response <- request("//data/tables?tableTypes=255")

    tables <- c()
    for (val in content(response, as="parsed")) {
      tables <- c(tables, val$tableName)
    }
    tables
  }
)

#' RAMM table schema.
#' @name Ramm_get_table_schema
#' @param table_name name of table in RAMM database
#' @return table schema object
NULL
Ramm$methods(
  get_table_schema = function (table_name) {
    content(
      request(paste("//schema/", table_name, "?loadType=3", sep="")),
      as="parsed"
    )
  }
)

#' List of columns in RAMM table.
#' @name Ramm_get_column_names
#' @param table_name name of table in RAMM database
#' @param get_geometry TRUE if the list of columns should include a geometry
#' column (default: FALSE)
#' @return List of column names in table
NULL
Ramm$methods(
  get_column_names = function(table_name, get_geometry=FALSE) {
    columns = c()

    for (val in get_table_schema(table_name)) {
      columns <- c(columns, val$columnName)
    }

    if (get_geometry) {
      columns <- c(columns, "wkt")
    }

    columns
  }
)

Ramm$methods(
  query = function(
    table_name,
    filters=list(),
    skip=0,
    take=1,
    columns=c(),
    get_geometry=FALSE) {

    request_body <- build_request_body(
      filters,
      table_name,
      skip,
      take,
      columns,
      get_geometry
    )

    request(
      "//data/table",
      method = "POST",
      body = toJSON(request_body, auto_unbox=TRUE)
      )
  }
)

#' Retrieve data from a table in the RAMM database.
#' @name Ramm_get_data
#' @param table_name name of table in RAMM database
#' @param get_geometry TRUE if geometry data should be retrieved (default: FALSE)
#' @param filters list of filters
#' @param chunk_size number of rows to collect per packet (default: 5000)
#' @param column_names optional list of columns to retrieve. Retrieves all
#' columns by default.
#' @return data.frame
NULL
Ramm$methods(
  get_data = function (
    table_name,
    get_geometry=FALSE,
    filters=list(),
    chunk_size=5000,
    column_names=c()) {

    if (length(column_names) > 0) {
      df_columns <- column_names
      if (get_geometry) {
        df_columns <- c(df_columns, "wkt")
      }
    } else {
      df_columns <- get_column_names(
        table_name,
        get_geometry=get_geometry)
    }

    n_rows <- content(query(table_name, filters=filters), as="parsed")$total
    if (n_rows > 0) {
      n_chunks <- as.integer(ceiling(n_rows/chunk_size))
      print(paste("retrieving", n_rows, "rows from", table_name))

      for (ii in seq(1, n_chunks)) {
        response_content <- content(
          ramm$query(
            "roadnames",
            filters=filters,
            skip=(ii - 1)*chunk_size,
            take=chunk_size),
          as="parsed"
        )

        data_list = list()
        for (row in response_content$rows) {
          data_list <- rbind(data_list, row$values)
        }

        df <- as.data.frame(data_list, stringsAsFactors=FALSE)
        colnames(df) <- df_columns
      }
      df
    } else {
      print(filter)
      print("No data matches specified filter parameters.")
    }
  }
)

build_request_body = function(
  filters=list(),
  table_name="roadnames",
  skip=0,
  take=1,
  columns=c(),
  get_geometry=FALSE,
  expand_lookups=FALSE) {
    if (check_filters(filters)) {
      request_body = list(
        "filters" = filters,
        "expandLookups" = expand_lookups,
        "getGeometry" = get_geometry,
        "isLongitudeLatitude" = TRUE,
        "gridPaging" = list("skip" = skip, "take" = take),
        "excludeReplacedData" = TRUE,
        "returnEntityId" = FALSE,
        "tableName" = table_name,
        "loadType" = "All",
        "columns" = columns
      )

      if (length(columns) > 0) {
        request_body$loadType <- "Specified"
      }
      return(request_body)
    } else {
      stop("Invalid filters.")
    }
  }

check_filters = function(filters) {
  # Filters must be a list of named lists.
  msg <- "filters must be of the form: list(list('columnName' = '...', 'operator' = '...', 'value'= '...'), ...)"
  param_names <- c("columnName", "operator", "value")
  filters_valid = TRUE
  if (typeof(filters) != "list"){
    print(filters)
    print(msg)
    filters_valid = FALSE
  } else {
    if (length(filters) > 0) {
      for (ff in filters) {
        if (typeof(ff) != "list") {
          print(filters)
          print(msg)
          filters_valid = FALSE
          break
        } else {
          ff_param_names <- names(ff)
          for (pp in param_names) {
            if ( !(pp %in% ff_param_names) ) {
              print(filters)
              print(msg)
              filters_valid = FALSE
              break
            }
          }
        }
      }
    }
  }
  filters_valid
}

append_params = function (url, params) {
  for (. in kv(params)) {
      url <- param_set(url, key = URLencode(.$k), value = URLencode(.$v))
    }
  url
}
