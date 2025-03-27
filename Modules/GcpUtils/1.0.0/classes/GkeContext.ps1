enum GkeStatus {
    STATUS_UNSPECIFIED	#Not set.
    PROVISIONING	#The PROVISIONING state indicates the node pool is being created.
    RUNNING	#The RUNNING state indicates the node pool has been created and is fully usable.
    RUNNING_WITH_ERROR	#The RUNNING_WITH_ERROR state indicates the node pool has been created and is partially usable. Some error state has occurred and some functionality may be impaired. Customer may need to reissue a request or trigger a new update.
    RECONCILING	#The RECONCILING state indicates that some work is actively being done on the node pool, such as upgrading node software. Details can be found in the statusMessage field.
    STOPPING	#The STOPPING state indicates the node pool is being deleted.
    ERROR
}

class GkeInfo {
    [string]$ProjectID
    [string]$ProjectNumber
    [string]$Context
    [string]$Name
    [string]$Location
    [semver]$MASTER_VERSION #: 1.29.7-gke.1104000
    [ipaddress]$MASTER_IP    #  : 34.159.246.176
    [string]$MACHINE_TYPE   #: e2-standard-4
    [string]$NODE_VERSION   #: 1.29.7-gke.1008000 *
    [int]$NUM_NODES #     : 11
    [GkeStatus]$STATUS # RUNNING
}