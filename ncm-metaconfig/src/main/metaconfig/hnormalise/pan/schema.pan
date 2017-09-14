declaration template metaconfig/hnormalise/schema;

@{ Schema for hnormalise configuration, see
https://github.com/itkovian/hnormalise
}


include 'pan/types';

type hnormalise_logging = {
    "frequency": long(1000..1000000000)
};

type hnormalise_connection_tcp = {
    "host": type_host
    "port": long(2..65536)
};

type hnormalise_output_tcp = {
    "success": hnormalise_connection_tcp
    "failure": hnormalise_connection_tcp
};

type hnormalise_connection_zeromq = {
    "method": string with match(SELF, '^(pull|push)')
    "host": type_host
    "port": long(2..65536)
};

type hnormalise_output_zeromq = {
    "success": hnormalise_connection_zeromq
    "failure": hnormalise_connection_zeromq
};

type hnormalise_input = {
    "tcp" ? hnormalise_connection_tcp
    "zeromq" ? hnormalise_connection_zeromq
};

type hnormalise_output = {
    "tcp" ? hnormalise_output_tcp
    "zeromq" ? hnormalise_output_zeromq
};

type hnormalise = {
    "logging": hnormalise_logging
    "input": hnormalise_input
    "output": hnormalise_output
    "fields": string[][]
};
