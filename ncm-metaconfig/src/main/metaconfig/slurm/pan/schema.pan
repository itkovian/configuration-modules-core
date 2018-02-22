declaration template metaconfig/slurm/schema;

@{ Schema for slurm configuration, see
https://slurm.schedmd.com
}

include 'pan/types';


type slurm_conf_control = {
    'ControlMachine' : string
    'ControlAddr' ? string  # fixme: ipv4
    'BackupController' ? string
    'BackupAddr' ? string # fixme: ipv4
    'AuthType' : string with match(SELF, '^auth/(munge)$')
    'CheckpointType' ? string # e.g. checkpoint/none
    'CryptoType' : string
    'DisableRootJobs' : string with match(SELF, '^(YES|NO)$')
    'EnforcePartLimits': string with match(SELF, '^(YES|NO)$')
    #'Epilog'=
    #'EpilogSlurmctld'=
    'FirstJobId' ? long
    'MaxJobId' ? long
    #'GresTypes'=
    'GroupUpdateForce' ? long
    'GroupUpdateTime' ? long
    'JobCheckpointDir' : absolute_file_path
    #'JobCredentialPrivateKey'=
    #'JobCredentialPublicCertificate'=
    #'JobFileAppend'=0
    #'JobRequeue'=1
    'JobSubmitPlugins' ? string with match(SELF, '^lua$')
    #'KillOnBadExit'=0
    #'LaunchType'=launch/slurm
    #'Licenses'=foo    '4,bar'
    'MailProg' ? absolute_file_path
    'MaxJobCount' ? long
    'MaxStepCount' ? long
    'MaxTasksPerNode' ? long
    'MpiDefault' : string
    #'MpiParams'=ports=#-#
    'PluginDir' ? absolute_file_path
    #'PlugStackConfig'=
    'PrivateData' : string[]
    'ProctrackType' : string
    #'Prolog'=
    #'PrologFlags'=
    #'PrologSlurmctld'=
    #'PropagatePrioProcess'=0
    #'PropagateResourceLimits'=
    #'PropagateResourceLimitsExcept'=
    #'RebootProgram'=
    'ReturnToService' : long
    #'SallocDefaultCommand'=
};

type slurm_conf_process = {
    'SlurmctldPidFile' : absolute_file_path
    'SlurmctldPort' : long
    'SlurmdPidFile' : absolute_file_path
    'SlurmdPort' : long
    'SlurmdSpoolDir' : absolute_file_path
    'SlurmUser' : string = 'slurm'
    'SlurmdUser' ? string = 'root'
    #'SrunEpilog'=
    #'SrunProlog'=
    'StateSaveLocation' : absolute_file_path
    'SwitchType' : string
    #'TaskEpilog'=
    'TaskPlugin' : string[]
    'TaskPluginParam' : string with match(SELF, '^sched$')
    #'TaskProlog'=
    #'TopologyPlugin'=topology/tree
    #'TmpFS'=/tmp
    #'TrackWCKey'=no
    #'TreeWidth'=
    #'UnkillableStepProgram'=
    #'UsePAM'=0
};
#
#

type slurm_conf_timers = {
# TIMERS
    #'BatchStartTimeout'=10
    #'CompleteWait'=0
    #'EpilogMsgTime'=2000
    #'GetEnvTimeout'=2
    #'HealthCheckInterval'=0
    #'HealthCheckProgram'=
    'InactiveLimit' : long(0..)
    'KillWait' : long(0..)
    #'MessageTimeout'=10
    #'ResvOverRun'=0
    'MinJobAge' : long(0..)
    #'OverTimeLimit'=0
    'SlurmctldTimeout' : long(0..)
    'SlurmdTimeout' : long(0..)
    #'UnkillableStepTimeout'=60
    #'VSizeFactor'=0
    'Waittime' : long(0..)
};

#
#
# SCHEDULING
type slurm_conf_scheduling = {
    'DefMemPerCPU' ? long(0..)
    'DefMemPerNode' ? long(0..)
    'FastSchedule' : long
    'MaxMemPerNode' : long(0..)
    #'SchedulerTimeSlice'=30
    'SchedulerType' : string with match(SELF, '^sched/(backfill|builtin|hold)$$')
    'SchedulerParameters': string[]
    'SelectType' ? string with match(SELF, '^select/(bluegene|cons_res|cray|linear|serial)$')
    'SelectTypeParameters' ? string[]  # available options depend on the type. can we specify this?
};


#
#
# JOB PRIORITY
type slurm_conf_job_priority = {
    'PriorityFlags' ? string[]
    'PriorityType' : string with match(SELF, '^priority/(multifactor|basic)$')
    'PriorityDecayHalfLife' ? string
    'PriorityCalcPeriod' ? long(0..)
    'PriorityFavorSmall' ? string with match(SELF, '^(YES|NO)$')
    'PriorityMaxAge' ? string
    #'PriorityUsageResetPeriod'=
    'PriorityWeightAge' ? long(0..)
    'PriorityWeightFairshare' ? long(0..)
    'PriorityWeightJobSize' ? long(0..)
    'PriorityWeightPartition' ? long(0..)
    'PriorityWeightQOS' ? long(0..)
};

#
#
# LOGGING AND ACCOUNTING
type slurm_conf_accounting = {
    'AccountingStorageEnforce' ? string[]
    'AccountingStorageHost' ? string
    'AccountingStorageLoc' ? absolute_file_path
    #'AccountingStoragePass'=
    #'AccountingStoragePort'=
    'AccountingStorageType' ? string with match(SELF, '^accounting_storage/(filetxt|none|slurmdbd)$')
    #'AccountingStorageUser'=
    'AccountingStoreJobComment' ? string with match(SELF, '^(YES|NO)$')
    'ClusterName' : string
    #'DebugFlags'=
    'JobCompHost' ? string
    'JobCompLoc' ? string
    'JobCompPass' ? string
    'xJobCompPort' ? string
    'JobCompType' ? string with match(SELF, '^jobcomp/(elastcisearch|filetxt|mysql|none)$')
    'JobCompUser' ? string
    'JobContainerType'? string with match(SELF, '^job_container/(none)$')
    'JobAcctGatherFrequency' ? long(0..)
    'JobAcctGatherType' ? string with match(SELF, '^jobacct_gather/(cgroup|linux|none)$')
};

type slurm_conf_logging = {
    'SlurmctldDebug' ? long(0..)
    'SlurmctldLogFile' : absolute_file_path
    'SlurmdDebug' ? long(0..)
    'SlurmdLogFile' : absolute_file_path
    #'SlurmdLogFile'=
    #'SlurmSchedLogFile'=
    #'SlurmSchedLogLevel'=
};

# POWER SAVE SUPPORT FOR IDLE NODES (optional)
type slurm_conf_power = {
    #'SuspendProgram'=
    #'ResumeProgram'=
    #'SuspendTimeout'=
    #'ResumeTimeout'=
    #'ResumeRate'=
    #'SuspendExcNodes'=
    #'SuspendExcParts'=
    #'SuspendRate'=
    #'SuspendTime'=
};

# COMPUTE NODES
type slurm_conf_compute_nodes = {
    'NodeName' : string[]
    'CPUs' : long(0..)
    'Sockets' : long(0..)
    'CoresPerSocket' : long(0..)
    'ThreadsPerCore' : long(0..)
    'State' : string with match(SELF, '^(UNKNOWN|UP|DOWN)$')
    'RealMemory': long(0..) # MiB
};

type slurm_conf_partition = {
    'PartitionName': string
    'Nodes' : string[]
    'Default' : string with match(SELF, '^(YES|NO)$')
    'MaxTime' : string
    'State' : string with match(SELF, '^(UP|DOWN|UNKNOWN)$')
    'DisableRootJobs' : string with match(SELF, '^(YES|NO)$')
};


type slurm_conf = {
    'control' : slurm_conf_control
    'process' : slurm_conf_process
    'timers' : slurm_conf_timers
    'scheduling' : slurm_conf_scheduling
    'priority' : slurm_conf_job_priority
    'accounting' : slurm_conf_accounting
    'logging' : slurm_conf_logging
    'power' ? slurm_conf_power
    'compute_nodes' : slurm_conf_compute_nodes
    'partition' : slurm_conf_partition
};



type slurm_cgroups_conf = {
    'CgroupAutomount' ? boolean
    'CgroupMountpoint' ? absolute_file_path

    # TASK/CGROUP PLUGIN

    'AllowedDevicesFile' ? absolute_file_path
    'AllowedKmemSpace' ? long(0..)
    'AllowedRAMSpace' ? long(0..)
    'AllowedSwapSpace' ? long(0..)
    'ConstrainCores' ? boolean
    'ConstrainDevices' ? boolean
    'ConstrainKmemSpace' ? boolean
    'ConstrainRAMSpace' ? boolean
    'ConstrainSwapSpace' ? boolean
    'MaxRAMPercent' ? double
    'MaxSwapPercent' ? double
    'MaxKmemPercent' ? double
    'MemorySwappiness' ? long(0..100)
    'MinKmemSpace' ? long(0..)
    'MinRAMSpace' ? long(0..)
    'TaskAffinity' ? boolean
};

type slurm_spank_plugin = {
    'required' : choice('required', 'optional')
    'plugin' : absolute_file_path
    'arguments': string[]
};


type slurm_spank_includes = {
    'directory' : absolute_file_path
};

type slurm_spank_conf = {
    'plugins' ? slurm_spank_plugin[]
    'includes' ? slurm_spank_includes[]
};

type slurm_dbd_conf = {
    'ArchiveDir' ? absolute_file_path
    'ArchiveEvents' ? boolean
    'ArchiveJobs' ? boolean
    'ArchiveResvs' ? boolean
    'ArchiveScript' ? absolute_file_path
    'ArchiveSteps' ? boolean
    'ArchiveSuspend' ? boolean
    'ArchiveTXN' ? boolean
    'ArchiveUsage' ? boolean
    'AuthInfo' ? string
    'AuthType' ? choice('auth/none', 'auth/munge')
    'CommitDelay' ? long(1..)
    'DbdBackupHost' ? string
    'DbdAddr' ? string
    'DbdHost' ? string
    'DbdPort' ? long(0..) # must be equal to the AccountingStoragePort parameter in the slurm.conf
    'DebugFlags' ? choice('DB_ARCHIVE', 'DB_ASSOC', 'DB_EVENT', 'DB_JOB', 'DB_QOS', 'DB_QUERY', 'DB_RESERVATION', 'DB_RESOURCE', 'DB_STEP', 'DB_USAGE', 'DB_WCKEY', 'FEDERATION')[]
    'DebugLevel' ? choice('quiet', 'fatal', 'error', 'info', 'verbose', 'debug', 'debug2', 'debug3', 'debug4', 'debug5')
    'DebugLevelSyslog' ? choice('quiet', 'fatal', 'error', 'info', 'verbose', 'debug', 'debug2', 'debug3', 'debug4', 'debug5')
    'DefaultQOS' ? string
    'LogFile' ? absolute_file_path
    'LogTimeFormat' ? choice("iso8601", "iso8601_ms", "rfc5424", "rfc5424_ms", "clock", "short")
    'MaxQueryTimeRange' ? long(0..)  # unsure of this type
    'MessageTimeout' ? long(0..)
    'PidFile' ? absolute_file_path
    'PluginDir' ? absolute_file_path
    'PrivateData' ? choice( 'accounts', 'events', 'jobs', 'reservations', 'usage', 'users')[]
    'PurgeEventAfter' ? long(1..)  # these can either be a number (indicating months) or a number with days or hours suffix
    'PurgeJobAfter' ? long(1..)  # these can either be a number (indicating months) or a number with days or hours suffix
    'PurgeResvAfter' ? long(1..)  # these can either be a number (indicating months) or a number with days or hours suffix
    'PurgeStepAfter' ? long(1..)  # these can either be a number (indicating months) or a number with days or hours suffix
    'PurgeSuspendAfter' ? long(1..)  # these can either be a number (indicating months) or a number with days or hours suffix
    'PurgeTXNAfter' ? long(1..)  # these can either be a number (indicating months) or a number with days or hours suffix
    'PurgeUsageAfter' ? long(1..)  # these can either be a number (indicating months) or a number with days or hours suffix
    'SlurmUser' ? string
    'StorageHost' ? string
    'StorageBackupHost' ? string
    'StorageLoc' ? absolute_file_path
    'StoragePass' ? string
    'StoragePort' ? long(0..)
    'StorageType' ? choice("accounting_storage/mysql")
    'StorageUser' ? string
    'TCPTimeout' ? long(0..)
    'TrackWCKey' ? boolean
    'TrackSlurmctldDown' ? boolean
};
