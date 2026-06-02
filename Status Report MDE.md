## KQL For MDAV Mode
```Kusto
DeviceTvmInfoGathering
| extend AvModeRaw = tostring(AdditionalFields.AvMode)
| where isnotnull(AvModeRaw)
| distinct DeviceId, AvModeRaw
| extend AvMode = case(
    AvModeRaw == "0", "Active",
    AvModeRaw == "1", "Passive",
    AvModeRaw == "2", "Disabled",
    AvModeRaw == "4", "EDR Blocked",
    AvModeRaw == "5", "PassiveAudit",
    "Unknown"
)
| summarize DeviceCount = count() by AvMode
| order by DeviceCount desc
```


## KQL For MDAV Engine, Sig, Platform, Version
```KQL
//MDAV Engine, Sig, Platform, Version
let expiringPublishdate = ago(8d);
DeviceTvmInfoGathering
| extend AvMode = iif(tostring(AdditionalFields.AvMode) == '0', 'Active', iif(tostring(AdditionalFields.AvMode) == '1', 'Passive',iif(tostring(AdditionalFields.AvMode) == '2', 'Disabled', iif(tostring(AdditionalFields.AvMode) == '5', 'PassiveAudit',iif(tostring(AdditionalFields.AvMode) == '4', 'EDR Blocked' ,'Unknown')))))  
| extend AvIsSignatureUpToDateTemp = tostring(AdditionalFields.AvIsSignatureUptoDate), DataRefreshTimestamp= Timestamp,
AvIsPlatformUptodateTemp=tostring(AdditionalFields.AvIsPlatformUptodate),
AvIsEngineUptodateTemp = tostring(AdditionalFields.AvIsEngineUptodate), 
AvSignatureDataRefreshTime = todatetime(AdditionalFields.AvSignatureDataRefreshTime), 
AvSignaturePublishTime = todatetime(AdditionalFields.AvSignaturePublishTime),
AvSignatureVersion =  tostring(AdditionalFields.AvSignatureVersion),
AvEngineVersion =  tostring(AdditionalFields.AvEngineVersion),
AvPlatformVersion =  tostring(AdditionalFields.AvPlatformVersion)
| extend AvIsSignatureUpToDate = iif(((((isnull(AvIsSignatureUpToDateTemp)
or (isnull(AvSignatureDataRefreshTime)))
or (isnull(AvSignaturePublishTime))))
or (AvIsSignatureUpToDateTemp == "true"
and AvSignaturePublishTime < expiringPublishdate)), "Unknown", tostring(AvIsSignatureUpToDateTemp))
| extend AvIsEngineUpToDate = iif(((((isnull(AvIsEngineUptodateTemp)
or (isnull(AvSignatureDataRefreshTime)))
or (isnull(AvSignaturePublishTime)))
or (AvSignatureDataRefreshTime < expiringPublishdate))
or (AvSignaturePublishTime < expiringPublishdate)), "Unknown", tostring(AvIsEngineUptodateTemp))
| extend AvIsPlatformUpToDate = iif(((((isnull(AvIsPlatformUptodateTemp)
or (isnull(AvSignatureDataRefreshTime)))
or (isnull(AvSignaturePublishTime)))
or (AvSignatureDataRefreshTime < expiringPublishdate))
or (AvSignaturePublishTime < expiringPublishdate)), "Unknown", tostring(AvIsPlatformUptodateTemp))
| project DeviceId, DeviceName, DataRefreshTimestamp, OSPlatform, AvMode, AvSignatureVersion, AvIsSignatureUpToDate, AvEngineVersion, AvIsEngineUpToDate, AvPlatformVersion , AvIsPlatformUpToDate, AvSignaturePublishTime, AvSignatureDataRefreshTime
| where DataRefreshTimestamp > ago(6h)
| order by DeviceName asc
| limit 10000
```
## Picture of output
<img width="2931" height="1172" alt="image" src="https://github.com/user-attachments/assets/bed528e8-eb87-4bd7-8055-6e452dd9dab4" />


