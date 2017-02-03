unique template metaconfig/logstash/config;

include metaconfig/logstash/version;
include format("metaconfig/logstash/config_%s", METACONFIG_LOGSTASH_VERSION);

