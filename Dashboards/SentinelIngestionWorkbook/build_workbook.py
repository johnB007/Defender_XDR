import json, os

out = os.path.join(os.path.dirname(__file__), "SentinelIngestionWorkbook.json")

# --- helper: build a full device-tab group ---
def device_tab(table, tab_value, group_name, chart_name, selector_name,
               extra_vendor_cols, extra_vendor_labels,
               drilldown_extra_summarize, drilldown_extra_labels,
               context_tables):
    """Build a complete device tab with graph + vendor table + full drilldown."""
    base_filter = (
        f"{table}\n"
        "| where InitiatingProcessVersionInfoCompanyName !startswith 'Microsoft'\n"
        "    and InitiatingProcessVersionInfoCompanyName !startswith 'Google'\n"
        "    and isnotempty(InitiatingProcessVersionInfoCompanyName)\n"
    )
    items = []
    # 1) Bar chart
    items.append({
        "type": 3,
        "content": {
            "version": "KqlItem/1.0",
            "query": base_filter + f"| summarize EventCount=count() by InitiatingProcessVersionInfoCompanyName, bin(TimeGenerated, 1d)",
            "size": 2,
            "timeContextFromParameter": "TimePicker",
            "queryType": 0,
            "resourceType": "microsoft.operationalinsights/workspaces",
            "visualization": "barchart",
            "chartSettings": {"createOtherGroup": 50}
        },
        "name": chart_name
    })
    # 2) Vendor summary table (click to drill)
    vendor_q = base_filter + f"| summarize EventCount=count(), UniqueDevices=dcount(DeviceName){extra_vendor_cols} by InitiatingProcessVersionInfoCompanyName\n| order by EventCount desc"
    fmt = [
        {"columnMatch": "EventCount", "formatter": 4, "formatOptions": {"palette": "blue", "showBorder": False}},
        {"columnMatch": "UniqueDevices", "formatter": 4, "formatOptions": {"palette": "green", "showBorder": False}}
    ]
    lbl = [
        {"columnId": "InitiatingProcessVersionInfoCompanyName", "label": "Vendor (Company)"},
        {"columnId": "EventCount", "label": "Event Count"},
        {"columnId": "UniqueDevices", "label": "Unique Devices"},
    ] + extra_vendor_labels
    items.append({
        "type": 3,
        "content": {
            "version": "KqlItem/1.0",
            "query": vendor_q,
            "size": 1,
            "title": "Click a vendor row to drill down  \u25bc",
            "timeContextFromParameter": "TimePicker",
            "exportFieldName": "InitiatingProcessVersionInfoCompanyName",
            "exportParameterName": "SelectedVendor",
            "queryType": 0,
            "resourceType": "microsoft.operationalinsights/workspaces",
            "visualization": "table",
            "gridSettings": {
                "formatters": fmt,
                "filter": True,
                "sortBy": [{"itemKey": "EventCount", "sortOrder": 2}],
                "rowLimit": 100,
                "labelSettings": lbl
            }
        },
        "name": selector_name
    })
    # 3) Drilldown hint
    items.append({
        "type": 1,
        "content": {"json": f"---\n### Drilldown: **{{SelectedVendor}}** \u2014 {table}\nDetailed process info, file descriptions, paths, sizes, and device context for spike investigation.", "style": "info"},
        "conditionalVisibility": {"parameterName": "SelectedVendor", "comparison": "isNotEqualTo", "value": ""},
        "name": f"hint-{tab_value}-drilldown"
    })
    # 4) Full process detail drilldown
    proc_q = (
        f"{table}\n"
        "| where InitiatingProcessVersionInfoCompanyName == '{SelectedVendor}'\n"
        "| summarize\n"
        "    EventCount=count(),\n"
        "    UniqueDevices=dcount(DeviceName)" + drilldown_extra_summarize + "\n"
        "    by InitiatingProcessVersionInfoCompanyName,\n"
        "       InitiatingProcessVersionInfoProductName,\n"
        "       InitiatingProcessVersionInfoFileDescription,\n"
        "       InitiatingProcessVersionInfoInternalFileName,\n"
        "       InitiatingProcessVersionInfoOriginalFileName,\n"
        "       InitiatingProcessFileName,\n"
        "       InitiatingProcessFolderPath\n"
        "| order by EventCount desc"
    )
    proc_lbl = [
        {"columnId": "InitiatingProcessVersionInfoCompanyName", "label": "Company Name"},
        {"columnId": "InitiatingProcessVersionInfoProductName", "label": "Product Name"},
        {"columnId": "InitiatingProcessVersionInfoFileDescription", "label": "File Description"},
        {"columnId": "InitiatingProcessVersionInfoInternalFileName", "label": "Internal File Name"},
        {"columnId": "InitiatingProcessVersionInfoOriginalFileName", "label": "Original File Name"},
        {"columnId": "InitiatingProcessFileName", "label": "Process File Name"},
        {"columnId": "InitiatingProcessFolderPath", "label": "Process Folder Path"},
        {"columnId": "EventCount", "label": "Event Count"},
        {"columnId": "UniqueDevices", "label": "Unique Devices"},
    ] + drilldown_extra_labels
    items.append({
        "type": 3,
        "content": {
            "version": "KqlItem/1.0",
            "query": proc_q,
            "size": 1,
            "title": f"Process Detail \u2014 {{SelectedVendor}} ({table})",
            "timeContextFromParameter": "TimePicker",
            "queryType": 0,
            "resourceType": "microsoft.operationalinsights/workspaces",
            "visualization": "table",
            "gridSettings": {
                "formatters": [
                    {"columnMatch": "EventCount", "formatter": 4, "formatOptions": {"palette": "blue", "showBorder": False}},
                    {"columnMatch": "UniqueDevices", "formatter": 4, "formatOptions": {"palette": "green", "showBorder": False}}
                ],
                "filter": True,
                "sortBy": [{"itemKey": "EventCount", "sortOrder": 2}],
                "rowLimit": 250,
                "exportAllFields": True,
                "labelSettings": proc_lbl
            }
        },
        "conditionalVisibility": {"parameterName": "SelectedVendor", "comparison": "isNotEqualTo", "value": ""},
        "name": f"drilldown-{tab_value}-process"
    })
    # 5) Context-specific tables
    for ct in context_tables:
        items.append({
            "type": 3,
            "content": {
                "version": "KqlItem/1.0",
                "query": ct["query"],
                "size": 1,
                "title": ct["title"],
                "timeContextFromParameter": "TimePicker",
                "queryType": 0,
                "resourceType": "microsoft.operationalinsights/workspaces",
                "visualization": "table",
                "gridSettings": {
                    "formatters": [{"columnMatch": "EventCount", "formatter": 4, "formatOptions": {"palette": "purple", "showBorder": False}}],
                    "filter": True,
                    "sortBy": [{"itemKey": "EventCount", "sortOrder": 2}],
                    "exportAllFields": True,
                    "labelSettings": ct.get("labelSettings", [])
                }
            },
            "conditionalVisibility": {"parameterName": "SelectedVendor", "comparison": "isNotEqualTo", "value": ""},
            "name": ct["name"]
        })
    # 6) Top devices
    items.append({
        "type": 3,
        "content": {
            "version": "KqlItem/1.0",
            "query": f"{table}\n| where InitiatingProcessVersionInfoCompanyName == '{{SelectedVendor}}'\n| summarize EventCount=count(), UniqueProcesses=dcount(InitiatingProcessFileName) by DeviceName\n| order by EventCount desc\n| take 50",
            "size": 1,
            "title": f"Top 50 Devices \u2014 {{SelectedVendor}} ({table})",
            "timeContextFromParameter": "TimePicker",
            "queryType": 0,
            "resourceType": "microsoft.operationalinsights/workspaces",
            "visualization": "table",
            "gridSettings": {
                "formatters": [{"columnMatch": "EventCount", "formatter": 4, "formatOptions": {"palette": "blue", "showBorder": False}}],
                "filter": True,
                "sortBy": [{"itemKey": "EventCount", "sortOrder": 2}],
                "exportAllFields": True,
                "labelSettings": [
                    {"columnId": "DeviceName", "label": "Device Name"},
                    {"columnId": "EventCount", "label": "Event Count"},
                    {"columnId": "UniqueProcesses", "label": "Unique Processes"}
                ]
            }
        },
        "conditionalVisibility": {"parameterName": "SelectedVendor", "comparison": "isNotEqualTo", "value": ""},
        "name": f"drilldown-{tab_value}-devices"
    })
    # 7) Daily trend line chart
    items.append({
        "type": 3,
        "content": {
            "version": "KqlItem/1.0",
            "query": f"{table}\n| where InitiatingProcessVersionInfoCompanyName == '{{SelectedVendor}}'\n| summarize EventCount=count() by bin(TimeGenerated, 1d)\n| order by TimeGenerated asc",
            "size": 0,
            "title": f"Daily Event Trend \u2014 {{SelectedVendor}} ({table})",
            "timeContextFromParameter": "TimePicker",
            "queryType": 0,
            "resourceType": "microsoft.operationalinsights/workspaces",
            "visualization": "linechart"
        },
        "conditionalVisibility": {"parameterName": "SelectedVendor", "comparison": "isNotEqualTo", "value": ""},
        "name": f"drilldown-{tab_value}-trend"
    })
    return {
        "type": 12,
        "content": {
            "version": "NotebookGroup/1.0",
            "groupType": "editable",
            "title": f"{table} \u2014 Full Detail Drilldown",
            "items": items
        },
        "conditionalVisibility": {"parameterName": "Tab", "comparison": "isEqualTo", "value": tab_value},
        "name": group_name
    }

# --- helper: CISO overview tab ---
def ciso_tab(title, tab_value, group_name, query_chart, query_table, query_trend_line, query_trend_table, filter_clause, pct_label):
    items = [
        {"type": 3, "content": {"version": "KqlItem/1.0", "query": query_chart, "size": 2, "timeContextFromParameter": "TimePicker", "queryType": 0, "resourceType": "microsoft.operationalinsights/workspaces", "visualization": "barchart"}, "name": f"chart-{tab_value}"},
        {"type": 1, "content": {"json": f"### {title}\nClick a **DataType** row to see daily trend below.", "style": "info"}, "name": f"hint-{tab_value}-table"},
        {"type": 3, "content": {"version": "KqlItem/1.0", "query": query_table, "size": 1, "title": f"Data Types \u2014 Ranked by Total GB", "timeContextFromParameter": "TimePicker", "exportFieldName": "DataType", "exportParameterName": "SelectedDataType", "queryType": 0, "resourceType": "microsoft.operationalinsights/workspaces", "visualization": "table", "gridSettings": {"formatters": [{"columnMatch": "Total_GB", "formatter": 4, "formatOptions": {"palette": "red", "showBorder": False}}, {"columnMatch": pct_label, "formatter": 4, "formatOptions": {"palette": "orange", "showBorder": False}}, {"columnMatch": "Peak_Day_GB", "formatter": 4, "formatOptions": {"palette": "magenta", "showBorder": False}}], "filter": True, "sortBy": [{"itemKey": "Total_GB", "sortOrder": 2}], "labelSettings": [{"columnId": "DataType", "label": "Data Type"}, {"columnId": "Total_GB", "label": "Total (GB)"}, {"columnId": pct_label, "label": "% of Total"}, {"columnId": "Daily_Avg_GB", "label": "Daily Avg (GB)"}, {"columnId": "Peak_Day_GB", "label": "Peak Day (GB)"}, {"columnId": "Days_Active", "label": "Days Active"}]}}, "name": f"table-{tab_value}-summary"},
        {"type": 1, "content": {"json": "### Daily Trend for: **{SelectedDataType}**", "style": "info"}, "conditionalVisibility": {"parameterName": "SelectedDataType", "comparison": "isNotEqualTo", "value": ""}, "name": f"hint-{tab_value}-drilldown"},
        {"type": 3, "content": {"version": "KqlItem/1.0", "query": query_trend_line, "size": 0, "title": "Daily Ingestion Trend \u2014 {SelectedDataType}", "timeContextFromParameter": "TimePicker", "queryType": 0, "resourceType": "microsoft.operationalinsights/workspaces", "visualization": "linechart"}, "conditionalVisibility": {"parameterName": "SelectedDataType", "comparison": "isNotEqualTo", "value": ""}, "name": f"chart-{tab_value}-drilldown"},
        {"type": 3, "content": {"version": "KqlItem/1.0", "query": query_trend_table, "size": 1, "title": "Daily Ingestion Detail \u2014 {SelectedDataType} (exportable)", "timeContextFromParameter": "TimePicker", "queryType": 0, "resourceType": "microsoft.operationalinsights/workspaces", "visualization": "table", "gridSettings": {"formatters": [{"columnMatch": "Ingestion_GB", "formatter": 4, "formatOptions": {"palette": "blue", "showBorder": False}}], "filter": True, "sortBy": [{"itemKey": "Day", "sortOrder": 2}], "exportAllFields": True}}, "conditionalVisibility": {"parameterName": "SelectedDataType", "comparison": "isNotEqualTo", "value": ""}, "name": f"table-{tab_value}-drilldown"}
    ]
    return {
        "type": 12, "name": group_name,
        "content": {"version": "NotebookGroup/1.0", "groupType": "editable", "title": title, "items": items},
        "conditionalVisibility": {"parameterName": "Tab", "comparison": "isEqualTo", "value": tab_value}
    }

# ============ BUILD WORKBOOK ============
wb = {
    "version": "Notebook/1.0",
    "items": [],
    "fallbackResourceIds": ["/subscriptions/059a6208-97b5-48d7-ad37-4005e57ff26c/resourcegroups/daf-sentinel-prod/providers/microsoft.operationalinsights/workspaces/milz-operations-prod-log"],
    "fromTemplateId": "sentinel-UserWorkbook",
    "$schema": "https://github.com/Microsoft/Application-Insights-Workbooks/blob/master/schema/workbook.json"
}

# Parameters
wb["items"].append({
    "type": 9,
    "content": {
        "version": "KqlParameterItem/1.0",
        "parameters": [
            {"id": "2c540b4a-e890-4647-9bbd-186d7e780f00", "version": "KqlParameterItem/1.0", "name": "TimePicker", "label": "Time Picker", "type": 4, "typeSettings": {"selectableValues": [{"durationMs": 604800000}, {"durationMs": 1209600000}, {"durationMs": 2592000000}, {"durationMs": 5184000000}, {"durationMs": 7776000000}], "allowCustom": True}, "timeContext": {"durationMs": 86400000}, "value": {"durationMs": 604800000}},
            {"id": "f02f5fed-3e80-409d-89d4-9b8504e3940e", "version": "KqlParameterItem/1.0", "name": "Help", "label": "Show Help", "type": 10, "isRequired": True, "typeSettings": {"additionalResourceOptions": [], "showDefault": False}, "jsonData": "[{ \"value\": \"Yes\", \"label\": \"Yes\"},\r\n {\"value\": \"No\", \"label\": \"No\", \"selected\":true }]"},
            {"id": "a1b2c3d4-0001-0001-0001-000000000001", "version": "KqlParameterItem/1.0", "name": "SelectedDataType", "label": "Selected Data Type", "type": 1, "isRequired": False, "value": ""},
            {"id": "a1b2c3d4-0002-0002-0002-000000000002", "version": "KqlParameterItem/1.0", "name": "SelectedVendor", "label": "Selected Vendor", "type": 1, "isRequired": False, "value": ""}
        ],
        "style": "pills", "queryType": 0, "resourceType": "microsoft.operationalinsights/workspaces"
    },
    "name": "parameters - 8"
})

# Help text
wb["items"].append({
    "type": 1,
    "content": {"json": "This workbook gives an overall picture of the current Sentinel Ingestion broken down in size of ingestion per day by the Time Range you choose (7,14,30,60,90 days or custom time frame)\r\n\r\nAdditionally, you can drill down into Device related categories to see the counts coming from specific vendor processes. Since the vast majority are either Microsoft, Google, or blank (no vendor) we focus on the remaining vendors.\r\n\r\nFor questions please contact Keith Abluton(keithab@microsoft.com)", "style": "upsell"},
    "conditionalVisibility": {"parameterName": "Help", "comparison": "isEqualTo", "value": "Yes"},
    "name": "Header Text"
})

# Tabs
wb["items"].append({
    "type": 11,
    "content": {
        "version": "LinkItem/1.0", "style": "tabs",
        "links": [
            {"id": "fce10cb7-80a8-4d19-a69b-be812030e765", "cellValue": "Tab", "linkTarget": "parameter", "linkLabel": "Sentinel Ingestion-Total", "subTarget": "First", "preText": "Sentinel Ingestion", "style": "link"},
            {"id": "cdc1777f-1954-41be-90c8-f018f1df8777", "cellValue": "Tab", "linkTarget": "parameter", "linkLabel": "Ingestion - Non Device Related", "subTarget": "Fifth", "style": "link"},
            {"id": "56855807-bd3a-449e-b04d-89ff15b32fbb", "cellValue": "Tab", "linkTarget": "parameter", "linkLabel": "Device Tables (Breakout)", "subTarget": "Second", "style": "link"},
            {"id": "f203ab7e-f558-42af-ab9f-fd9cc157a81f", "cellValue": "Tab", "linkTarget": "parameter", "linkLabel": "DeviceEvents", "subTarget": "Ninth", "style": "link"},
            {"id": "3ac2f176-2956-458f-ae98-2b1ff1c68ecb", "cellValue": "Tab", "linkTarget": "parameter", "linkLabel": "Device File Events", "subTarget": "Third", "style": "link"},
            {"id": "84761ce1-49a1-47fe-9b31-ec768be709a8", "cellValue": "Tab", "linkTarget": "parameter", "linkLabel": "Device Process Events", "subTarget": "Sixth", "style": "link"},
            {"id": "d9d77d24-49d7-4f6a-ae50-3b165911b8b0", "cellValue": "Tab", "linkTarget": "parameter", "linkLabel": "Device Network Events", "subTarget": "Fourth", "style": "link"},
            {"id": "ccdc3e2b-cf28-4dde-bf86-08f3845ef7ed", "cellValue": "Tab", "linkTarget": "parameter", "linkLabel": "Device Registry Events", "subTarget": "Seventh", "style": "link"},
            {"id": "a04acd0f-a3fa-4c72-b514-bb9240b617a4", "cellValue": "Tab", "linkTarget": "parameter", "linkLabel": "Device Image Load Events", "subTarget": "Eighth", "style": "link"}
        ]
    },
    "name": "links - 3"
})

# ===== TAB 1: Sentinel Ingestion Total (CISO) =====
wb["items"].append(ciso_tab(
    "Sentinel Ingestion \u2014 CISO Overview", "First", "Ingestion",
    "Usage\n| where IsBillable==true\n| summarize Ingestion_GB=sum(Quantity)/1024 by bin(TimeGenerated,1d), DataType",
    "let TotalGB = toscalar(Usage\n| where IsBillable==true\n| summarize sum(Quantity)/1024);\nUsage\n| where IsBillable==true\n| summarize Total_GB=round(sum(Quantity)/1024,2), Daily_Avg_GB=round(avg(Quantity)/1024,2), Peak_Day_GB=round(max(Quantity)/1024,2), Days_Active=dcount(bin(TimeGenerated,1d)) by DataType\n| extend Pct_of_Total=round(Total_GB / TotalGB * 100, 1)\n| project DataType, Total_GB, Pct_of_Total, Daily_Avg_GB, Peak_Day_GB, Days_Active\n| order by Total_GB desc",
    "Usage\n| where IsBillable==true\n| where DataType == '{SelectedDataType}'\n| summarize Ingestion_GB=round(sum(Quantity)/1024,2) by Day=bin(TimeGenerated,1d)\n| order by Day asc",
    "Usage\n| where IsBillable==true\n| where DataType == '{SelectedDataType}'\n| summarize Ingestion_GB=round(sum(Quantity)/1024,3) by Day=bin(TimeGenerated,1d)\n| order by Day desc",
    "", "Pct_of_Total"
))

# ===== TAB 2: Device Tables Breakout (CISO) =====
dev_types = "('DeviceEvents','DeviceFileEvents','DeviceNetworkEvents','DeviceProcessEvents','DeviceImageLoadEvents','DeviceLogonEvents','DeviceNetworkInfo','DeviceRegistryEvents')"
wb["items"].append(ciso_tab(
    "Device Tables Breakout \u2014 CISO Overview", "Second", "Device Related Tables",
    f"Usage\n| where DataType in {dev_types}\n| summarize Ingestion_GB=sum(Quantity)/1024 by bin(TimeGenerated,1d), DataType",
    f"let TotalDeviceGB = toscalar(Usage\n| where DataType in {dev_types}\n| summarize sum(Quantity)/1024);\nUsage\n| where DataType in {dev_types}\n| summarize Total_GB=round(sum(Quantity)/1024,2), Daily_Avg_GB=round(avg(Quantity)/1024,2), Peak_Day_GB=round(max(Quantity)/1024,2), Days_Active=dcount(bin(TimeGenerated,1d)) by DataType\n| extend Pct_of_Device_Total=round(Total_GB / TotalDeviceGB * 100, 1)\n| project DataType, Total_GB, Pct_of_Device_Total, Daily_Avg_GB, Peak_Day_GB, Days_Active\n| order by Total_GB desc",
    f"Usage\n| where DataType == '{{SelectedDataType}}'\n| summarize Ingestion_GB=round(sum(Quantity)/1024,2) by Day=bin(TimeGenerated,1d)\n| order by Day asc",
    f"Usage\n| where DataType == '{{SelectedDataType}}'\n| summarize Ingestion_GB=round(sum(Quantity)/1024,3) by Day=bin(TimeGenerated,1d)\n| order by Day desc",
    "", "Pct_of_Device_Total"
))

# ===== TAB 5: Non Device (CISO) =====
wb["items"].append(ciso_tab(
    "Non-Device Ingestion \u2014 CISO Overview", "Fifth", "Non Device Events",
    "Usage\n| where IsBillable==true\n| where DataType !startswith 'Device'\n| summarize Ingestion_GB=sum(Quantity)/1024 by bin(TimeGenerated,1d), DataType",
    "let TotalNonDeviceGB = toscalar(Usage\n| where IsBillable==true\n| where DataType !startswith 'Device'\n| summarize sum(Quantity)/1024);\nUsage\n| where IsBillable==true\n| where DataType !startswith 'Device'\n| summarize Total_GB=round(sum(Quantity)/1024,2), Daily_Avg_GB=round(avg(Quantity)/1024,2), Peak_Day_GB=round(max(Quantity)/1024,2), Days_Active=dcount(bin(TimeGenerated,1d)) by DataType\n| extend Pct_of_NonDevice_Total=round(Total_GB / TotalNonDeviceGB * 100, 1)\n| project DataType, Total_GB, Pct_of_NonDevice_Total, Daily_Avg_GB, Peak_Day_GB, Days_Active\n| order by Total_GB desc",
    "Usage\n| where IsBillable==true\n| where DataType == '{SelectedDataType}'\n| summarize Ingestion_GB=round(sum(Quantity)/1024,2) by Day=bin(TimeGenerated,1d)\n| order by Day asc",
    "Usage\n| where IsBillable==true\n| where DataType == '{SelectedDataType}'\n| summarize Ingestion_GB=round(sum(Quantity)/1024,3) by Day=bin(TimeGenerated,1d)\n| order by Day desc",
    "", "Pct_of_NonDevice_Total"
))

# ===== TAB 3: DeviceFileEvents =====
wb["items"].append(device_tab(
    "DeviceFileEvents", "Third", "Device File Events", "chart-dfe", "selector-Third",
    extra_vendor_cols=", UniqueFiles=dcount(FileName), TotalFileSize_MB=round(sum(tolong(FileSize))/1048576.0,2)",
    extra_vendor_labels=[
        {"columnId": "UniqueFiles", "label": "Unique Files"},
        {"columnId": "TotalFileSize_MB", "label": "Total File Size (MB)"}
    ],
    drilldown_extra_summarize=",\n    AvgFileSize_KB=round(avg(tolong(FileSize))/1024.0,2),\n    TotalFileSize_MB=round(sum(tolong(FileSize))/1048576.0,2),\n    UniqueTargetFiles=dcount(FileName),\n    UniqueTargetPaths=dcount(FolderPath)",
    drilldown_extra_labels=[
        {"columnId": "AvgFileSize_KB", "label": "Avg File Size (KB)"},
        {"columnId": "TotalFileSize_MB", "label": "Total File Size (MB)"},
        {"columnId": "UniqueTargetFiles", "label": "Unique Target Files"},
        {"columnId": "UniqueTargetPaths", "label": "Unique Target Paths"}
    ],
    context_tables=[{
        "name": "drilldown-Third-actions",
        "title": "Action Types \u2014 {SelectedVendor} (DeviceFileEvents)",
        "query": "DeviceFileEvents\n| where InitiatingProcessVersionInfoCompanyName == '{SelectedVendor}'\n| summarize EventCount=count(), UniqueDevices=dcount(DeviceName), UniqueFiles=dcount(FileName) by ActionType\n| order by EventCount desc",
        "labelSettings": [{"columnId": "ActionType", "label": "Action Type"}, {"columnId": "EventCount", "label": "Event Count"}, {"columnId": "UniqueDevices", "label": "Unique Devices"}, {"columnId": "UniqueFiles", "label": "Unique Files"}]
    }]
))

# ===== TAB 4: DeviceNetworkEvents =====
wb["items"].append(device_tab(
    "DeviceNetworkEvents", "Fourth", "Device Network Events", "chart-dne", "selector-Fourth",
    extra_vendor_cols=", UniqueRemoteIPs=dcount(RemoteIP), UniqueRemoteUrls=dcount(RemoteUrl), UniquePorts=dcount(RemotePort)",
    extra_vendor_labels=[
        {"columnId": "UniqueRemoteIPs", "label": "Unique Remote IPs"},
        {"columnId": "UniqueRemoteUrls", "label": "Unique Remote URLs"},
        {"columnId": "UniquePorts", "label": "Unique Ports"}
    ],
    drilldown_extra_summarize=",\n    UniqueRemoteIPs=dcount(RemoteIP),\n    UniqueRemoteUrls=dcount(RemoteUrl)",
    drilldown_extra_labels=[
        {"columnId": "UniqueRemoteIPs", "label": "Unique Remote IPs"},
        {"columnId": "UniqueRemoteUrls", "label": "Unique Remote URLs"}
    ],
    context_tables=[{
        "name": "drilldown-Fourth-destinations",
        "title": "Top Remote Destinations \u2014 {SelectedVendor} (DeviceNetworkEvents)",
        "query": "DeviceNetworkEvents\n| where InitiatingProcessVersionInfoCompanyName == '{SelectedVendor}'\n| summarize EventCount=count(), UniqueDevices=dcount(DeviceName) by RemoteUrl, RemoteIP, RemotePort, Protocol, ActionType\n| order by EventCount desc\n| take 100",
        "labelSettings": [{"columnId": "RemoteUrl", "label": "Remote URL"}, {"columnId": "RemoteIP", "label": "Remote IP"}, {"columnId": "RemotePort", "label": "Remote Port"}, {"columnId": "Protocol", "label": "Protocol"}, {"columnId": "ActionType", "label": "Action Type"}, {"columnId": "EventCount", "label": "Event Count"}, {"columnId": "UniqueDevices", "label": "Unique Devices"}]
    }]
))

# ===== TAB 6: DeviceProcessEvents =====
wb["items"].append(device_tab(
    "DeviceProcessEvents", "Sixth", "Device Process Events", "chart-dpe", "selector-Sixth",
    extra_vendor_cols=", UniqueProcesses=dcount(FileName), UniqueCommandLines=dcount(ProcessCommandLine), UniqueAccounts=dcount(AccountName)",
    extra_vendor_labels=[
        {"columnId": "UniqueProcesses", "label": "Unique Processes"},
        {"columnId": "UniqueCommandLines", "label": "Unique Cmd Lines"},
        {"columnId": "UniqueAccounts", "label": "Unique Accounts"}
    ],
    drilldown_extra_summarize=",\n    UniqueAccounts=dcount(AccountName),\n    UniqueCommandLines=dcount(ProcessCommandLine)",
    drilldown_extra_labels=[
        {"columnId": "UniqueAccounts", "label": "Unique Accounts"},
        {"columnId": "UniqueCommandLines", "label": "Unique Cmd Lines"}
    ],
    context_tables=[
        {
            "name": "drilldown-Sixth-spawned",
            "title": "Spawned Process Detail \u2014 {SelectedVendor} (DeviceProcessEvents)",
            "query": "DeviceProcessEvents\n| where InitiatingProcessVersionInfoCompanyName == '{SelectedVendor}'\n| summarize EventCount=count(), UniqueDevices=dcount(DeviceName) by FileName, FolderPath, ProcessVersionInfoCompanyName, ProcessVersionInfoProductName, ProcessVersionInfoFileDescription\n| order by EventCount desc\n| take 100",
            "labelSettings": [{"columnId": "FileName", "label": "Spawned Process"}, {"columnId": "FolderPath", "label": "Spawned Folder Path"}, {"columnId": "ProcessVersionInfoCompanyName", "label": "Spawned Company"}, {"columnId": "ProcessVersionInfoProductName", "label": "Spawned Product"}, {"columnId": "ProcessVersionInfoFileDescription", "label": "Spawned File Desc"}, {"columnId": "EventCount", "label": "Event Count"}, {"columnId": "UniqueDevices", "label": "Unique Devices"}]
        },
        {
            "name": "drilldown-Sixth-actions",
            "title": "Action Types \u2014 {SelectedVendor} (DeviceProcessEvents)",
            "query": "DeviceProcessEvents\n| where InitiatingProcessVersionInfoCompanyName == '{SelectedVendor}'\n| summarize EventCount=count(), UniqueDevices=dcount(DeviceName) by ActionType\n| order by EventCount desc",
            "labelSettings": [{"columnId": "ActionType", "label": "Action Type"}, {"columnId": "EventCount", "label": "Event Count"}, {"columnId": "UniqueDevices", "label": "Unique Devices"}]
        }
    ]
))

# ===== TAB 7: DeviceRegistryEvents =====
wb["items"].append(device_tab(
    "DeviceRegistryEvents", "Seventh", "Device Registry Events", "chart-dre", "selector-Seventh",
    extra_vendor_cols=", UniqueRegKeys=dcount(RegistryKey), UniqueRegValues=dcount(RegistryValueName)",
    extra_vendor_labels=[
        {"columnId": "UniqueRegKeys", "label": "Unique Registry Keys"},
        {"columnId": "UniqueRegValues", "label": "Unique Registry Values"}
    ],
    drilldown_extra_summarize=",\n    UniqueRegKeys=dcount(RegistryKey)",
    drilldown_extra_labels=[
        {"columnId": "UniqueRegKeys", "label": "Unique Registry Keys"}
    ],
    context_tables=[{
        "name": "drilldown-Seventh-registry",
        "title": "Top Registry Keys & Values \u2014 {SelectedVendor} (DeviceRegistryEvents)",
        "query": "DeviceRegistryEvents\n| where InitiatingProcessVersionInfoCompanyName == '{SelectedVendor}'\n| summarize EventCount=count(), UniqueDevices=dcount(DeviceName) by RegistryKey, RegistryValueName, RegistryValueData, ActionType\n| order by EventCount desc\n| take 100",
        "labelSettings": [{"columnId": "RegistryKey", "label": "Registry Key"}, {"columnId": "RegistryValueName", "label": "Value Name"}, {"columnId": "RegistryValueData", "label": "Value Data"}, {"columnId": "ActionType", "label": "Action Type"}, {"columnId": "EventCount", "label": "Event Count"}, {"columnId": "UniqueDevices", "label": "Unique Devices"}]
    }]
))

# ===== TAB 8: DeviceImageLoadEvents =====
wb["items"].append(device_tab(
    "DeviceImageLoadEvents", "Eighth", "Device Image Load Events", "chart-dile", "selector-Eighth",
    extra_vendor_cols=", UniqueLoadedImages=dcount(FileName), TotalFileSize_MB=round(sum(tolong(FileSize))/1048576.0,2)",
    extra_vendor_labels=[
        {"columnId": "UniqueLoadedImages", "label": "Unique Loaded Images"},
        {"columnId": "TotalFileSize_MB", "label": "Total File Size (MB)"}
    ],
    drilldown_extra_summarize=",\n    UniqueLoadedImages=dcount(FileName),\n    AvgFileSize_KB=round(avg(tolong(FileSize))/1024.0,2),\n    TotalFileSize_MB=round(sum(tolong(FileSize))/1048576.0,2)",
    drilldown_extra_labels=[
        {"columnId": "UniqueLoadedImages", "label": "Unique Loaded Images"},
        {"columnId": "AvgFileSize_KB", "label": "Avg File Size (KB)"},
        {"columnId": "TotalFileSize_MB", "label": "Total File Size (MB)"}
    ],
    context_tables=[{
        "name": "drilldown-Eighth-images",
        "title": "Top Loaded Images (DLLs) \u2014 {SelectedVendor} (DeviceImageLoadEvents)",
        "query": "DeviceImageLoadEvents\n| where InitiatingProcessVersionInfoCompanyName == '{SelectedVendor}'\n| summarize EventCount=count(), UniqueDevices=dcount(DeviceName), FileSize_KB=round(avg(tolong(FileSize))/1024.0,2) by FileName, FolderPath, SHA256, ActionType\n| order by EventCount desc\n| take 100",
        "labelSettings": [{"columnId": "FileName", "label": "Loaded Image/DLL"}, {"columnId": "FolderPath", "label": "Image Path"}, {"columnId": "SHA256", "label": "SHA256"}, {"columnId": "ActionType", "label": "Action Type"}, {"columnId": "EventCount", "label": "Event Count"}, {"columnId": "UniqueDevices", "label": "Unique Devices"}, {"columnId": "FileSize_KB", "label": "Avg File Size (KB)"}]
    }]
))

# ===== TAB 9: DeviceEvents =====
wb["items"].append(device_tab(
    "DeviceEvents", "Ninth", "Device Events", "chart-de", "selector-Ninth",
    extra_vendor_cols=", UniqueActionTypes=dcount(ActionType), UniqueProcesses=dcount(InitiatingProcessFileName)",
    extra_vendor_labels=[
        {"columnId": "UniqueActionTypes", "label": "Unique Action Types"},
        {"columnId": "UniqueProcesses", "label": "Unique Processes"}
    ],
    drilldown_extra_summarize=",\n    UniqueActionTypes=dcount(ActionType)",
    drilldown_extra_labels=[
        {"columnId": "UniqueActionTypes", "label": "Unique Action Types"}
    ],
    context_tables=[{
        "name": "drilldown-Ninth-actions",
        "title": "Action Type Breakdown \u2014 {SelectedVendor} (DeviceEvents)",
        "query": "DeviceEvents\n| where InitiatingProcessVersionInfoCompanyName == '{SelectedVendor}'\n| summarize EventCount=count(), UniqueDevices=dcount(DeviceName), UniqueProcesses=dcount(InitiatingProcessFileName) by ActionType\n| order by EventCount desc",
        "labelSettings": [{"columnId": "ActionType", "label": "Action Type"}, {"columnId": "EventCount", "label": "Event Count"}, {"columnId": "UniqueDevices", "label": "Unique Devices"}, {"columnId": "UniqueProcesses", "label": "Unique Processes"}]
    }]
))

with open(out, "w", encoding="utf-8") as f:
    json.dump(wb, f, indent=2, ensure_ascii=False)

print(f"Written {os.path.getsize(out)} bytes to {out}")
