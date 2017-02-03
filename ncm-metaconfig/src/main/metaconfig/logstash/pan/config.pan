unique template metaconfig/logstash/config;

variable METACONFIG_LOGSTASH_VERSION ?= "1.2";

include format("metaconfig/logstash/config_%s", METACONFIG_LOGSTASH_VERSION);

