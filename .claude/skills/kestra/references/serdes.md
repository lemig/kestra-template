# SerDes (Serialization/Deserialization) Reference

Convert between data formats in Kestra workflows. The SerDes plugin enables transformations between CSV, JSON, Avro, Parquet, Excel, XML, and Ion formats.

## Table of Contents
1. [Understanding Ion Format](#understanding-ion-format)
2. [CSV Conversions](#csv-conversions)
3. [JSON Conversions](#json-conversions)
4. [Avro Conversions](#avro-conversions)
5. [Parquet Conversions](#parquet-conversions)
6. [Excel Conversions](#excel-conversions)
7. [XML Conversions](#xml-conversions)
8. [Common Patterns](#common-patterns)

## Understanding Ion Format

Kestra's internal storage uses **Amazon Ion** format by default. Ion is a superset of JSON that supports additional types (timestamps, decimals, binary).

**Flow of data:**
```
External Format → Ion (internal) → External Format
     CSV      →      Ion       →      JSON
     JSON     →      Ion       →      Parquet
     API      →      Ion       →      CSV
```

Most database queries and API responses store data as Ion files in internal storage, accessible via `outputs.taskId.uri`.

## CSV Conversions

### CSV to Ion
```yaml
- id: csv_to_ion
  type: io.kestra.plugin.serdes.csv.CsvToIon
  from: "{{ outputs.download.uri }}"
  # Optional configuration
  header: true  # First row is header (default: true)
  delimiter: ","  # Field delimiter (default: ,)
  skipRows: 0  # Skip N rows at start
```

### Ion to CSV
```yaml
- id: ion_to_csv
  type: io.kestra.plugin.serdes.csv.IonToCsv
  from: "{{ outputs.query.uri }}"
  # Optional configuration
  header: true  # Include header row
  delimiter: ","
```

### CSV Options
| Property | Description | Default |
|----------|-------------|---------|
| `header` | First row contains headers | `true` |
| `delimiter` | Field separator | `,` |
| `textQualifier` | Quote character | `"` |
| `skipRows` | Rows to skip at start | `0` |
| `nullValue` | String representing null | (empty) |

## JSON Conversions

### JSON to Ion
```yaml
- id: json_to_ion
  type: io.kestra.plugin.serdes.json.JsonToIon
  from: "{{ outputs.download.uri }}"
  # For newline-delimited JSON (NDJSON)
  newLine: true  # Each line is a JSON object
```

### Ion to JSON
```yaml
- id: ion_to_json
  type: io.kestra.plugin.serdes.json.IonToJson
  from: "{{ outputs.query.uri }}"
  newLine: true  # Output as NDJSON
```

### JSONL/NDJSON Processing
```yaml
tasks:
  - id: download_jsonl
    type: io.kestra.plugin.core.http.Download
    uri: "https://example.com/data.jsonl"
  
  - id: to_ion
    type: io.kestra.plugin.serdes.json.JsonToIon
    from: "{{ outputs.download_jsonl.uri }}"
    newLine: true
```

## Avro Conversions

### Ion to Avro
```yaml
- id: to_avro
  type: io.kestra.plugin.serdes.avro.IonToAvro
  from: "{{ outputs.convert.uri }}"
  datetimeFormat: "yyyy-MM-dd'T'HH:mm:ss"
  schema: |
    {
      "type": "record",
      "name": "User",
      "namespace": "com.example",
      "fields": [
        {"name": "id", "type": "string"},
        {"name": "name", "type": "string"},
        {"name": "created_at", "type": {"type": "long", "logicalType": "timestamp-millis"}}
      ]
    }
```

### Avro to Ion
```yaml
- id: avro_to_ion
  type: io.kestra.plugin.serdes.avro.AvroToIon
  from: "{{ outputs.download.uri }}"
```

### Avro Schema Types
| Avro Type | Description |
|-----------|-------------|
| `string` | Text |
| `int` | 32-bit integer |
| `long` | 64-bit integer |
| `float` | 32-bit float |
| `double` | 64-bit float |
| `boolean` | True/false |
| `bytes` | Binary data |
| `{"type": "long", "logicalType": "timestamp-millis"}` | Timestamp |

## Parquet Conversions

### Ion to Parquet
```yaml
- id: to_parquet
  type: io.kestra.plugin.serdes.parquet.IonToParquet
  from: "{{ outputs.query.uri }}"
  schema: |
    message DataRecord {
      required binary id (STRING);
      required binary name (STRING);
      required int64 amount;
      optional int64 timestamp (TIMESTAMP_MILLIS);
    }
```

### Avro to Parquet
```yaml
- id: avro_to_parquet
  type: io.kestra.plugin.serdes.parquet.AvroToParquet
  from: "{{ outputs.avro_data.uri }}"
```

### Parquet to Ion
```yaml
- id: parquet_to_ion
  type: io.kestra.plugin.serdes.parquet.ParquetToIon
  from: "{{ outputs.download.uri }}"
```

## Excel Conversions

### Excel to Ion
```yaml
- id: excel_to_ion
  type: io.kestra.plugin.serdes.excel.ExcelToIon
  from: "{{ outputs.download.uri }}"
  header: true
  sheetsTitle: "Sheet1"  # Specific sheet name
```

### Ion to Excel
```yaml
- id: ion_to_excel
  type: io.kestra.plugin.serdes.excel.IonToExcel
  from: "{{ outputs.query.uri }}"
  header: true
  sheetsTitle: "Report Data"
```

## XML Conversions

### XML to Ion
```yaml
- id: xml_to_ion
  type: io.kestra.plugin.serdes.xml.XmlToIon
  from: "{{ outputs.download.uri }}"
```

### Ion to XML
```yaml
- id: ion_to_xml
  type: io.kestra.plugin.serdes.xml.IonToXml
  from: "{{ outputs.query.uri }}"
  rootName: "records"
  elementName: "record"
```

## Common Patterns

### Database Query to CSV
```yaml
tasks:
  - id: query
    type: io.kestra.plugin.jdbc.postgresql.Query
    url: "{{ secret('DB_URL') }}"
    sql: SELECT * FROM users WHERE active = true
    store: true  # Store results in internal storage
  
  - id: to_csv
    type: io.kestra.plugin.serdes.csv.IonToCsv
    from: "{{ outputs.query.uri }}"
```

### API Response to Parquet
```yaml
tasks:
  - id: fetch_api
    type: io.kestra.plugin.core.http.Download
    uri: "https://api.example.com/data"
  
  - id: json_to_ion
    type: io.kestra.plugin.serdes.json.JsonToIon
    from: "{{ outputs.fetch_api.uri }}"
  
  - id: ion_to_parquet
    type: io.kestra.plugin.serdes.parquet.IonToParquet
    from: "{{ outputs.json_to_ion.uri }}"
    schema: |
      message Record {
        required binary id (STRING);
        required double value;
      }
```

### CSV to Python Processing
```yaml
tasks:
  - id: download
    type: io.kestra.plugin.core.http.Download
    uri: "{{ inputs.csv_url }}"
  
  - id: to_ion
    type: io.kestra.plugin.serdes.csv.CsvToIon
    from: "{{ outputs.download.uri }}"
  
  - id: back_to_csv
    type: io.kestra.plugin.serdes.csv.IonToCsv
    from: "{{ outputs.to_ion.uri }}"
  
  - id: process
    type: io.kestra.plugin.core.flow.WorkingDirectory
    inputFiles:
      data.csv: "{{ outputs.back_to_csv.uri }}"
    tasks:
      - id: python
        type: io.kestra.plugin.scripts.python.Script
        containerImage: python:slim
        beforeCommands:
          - pip install pandas
        script: |
          import pandas as pd
          df = pd.read_csv("data.csv")
          # Process data
          df.to_csv("output.csv", index=False)
        outputFiles:
          - "output.csv"
```

### Multi-Format ETL Pipeline
```yaml
id: multi_format_etl
namespace: company.data

tasks:
  # Extract from multiple sources
  - id: extract_csv
    type: io.kestra.plugin.core.http.Download
    uri: "{{ inputs.csv_source }}"
  
  - id: extract_json
    type: io.kestra.plugin.core.http.Download
    uri: "{{ inputs.json_source }}"
  
  # Convert to Ion (common format)
  - id: csv_to_ion
    type: io.kestra.plugin.serdes.csv.CsvToIon
    from: "{{ outputs.extract_csv.uri }}"
  
  - id: json_to_ion
    type: io.kestra.plugin.serdes.json.JsonToIon
    from: "{{ outputs.extract_json.uri }}"
    newLine: true
  
  # Merge in Python
  - id: merge
    type: io.kestra.plugin.core.flow.WorkingDirectory
    inputFiles:
      csv_data.csv: "{{ outputs.csv_to_ion.uri }}"
      json_data.json: "{{ outputs.json_to_ion.uri }}"
    tasks:
      - id: python_merge
        type: io.kestra.plugin.scripts.python.Script
        containerImage: python:slim
        beforeCommands:
          - pip install pandas
        script: |
          import pandas as pd
          df1 = pd.read_csv("csv_data.csv")
          df2 = pd.read_json("json_data.json", lines=True)
          merged = pd.concat([df1, df2])
          merged.to_parquet("merged.parquet")
        outputFiles:
          - "merged.parquet"
```

## Best Practices

1. **Use `store: true`** for database queries to get Ion files
2. **Avoid large in-memory data** - use SerDes to stream data through files
3. **Chain conversions** when needed: CSV → Ion → Parquet
4. **Specify schemas** for Avro/Parquet to ensure type safety
5. **Use WorkingDirectory** to pass files to Python/Shell tasks
