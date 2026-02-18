public with sharing class FieldCoercion {
  public static Object toFieldValue(Object value, Schema.DescribeFieldResult fieldDescribe) {
    if (value == null) {
      return null;
    }

    Schema.DisplayType fieldType = fieldDescribe.getType();

    if (value instanceof String) {
      String strValue = (String) value;
      switch on fieldType {
        when DATE {
          return Date.valueOf(strValue);
        }
        when DATETIME {
          String dtStr = strValue.replace('T', ' ');
          if (dtStr.endsWith('Z')) {
            dtStr = dtStr.substring(0, dtStr.length() - 1);
          }
          if (!dtStr.contains(' ')) {
            dtStr += ' 00:00:00';
          }
          return DateTime.valueOf(dtStr);
        }
        when BOOLEAN {
          return Boolean.valueOf(strValue);
        }
        when DOUBLE, CURRENCY, PERCENT {
          return Decimal.valueOf(strValue);
        }
        when INTEGER {
          return Integer.valueOf(strValue);
        }
        when TIME {
          List<String> parts = strValue.replace('Z', '').split(':');
          return Time.newInstance(
            Integer.valueOf(parts[0]),
            Integer.valueOf(parts[1]),
            parts.size() > 2 ? Integer.valueOf(parts[2].split('\\.')[0]) : 0,
            0
          );
        }
        when else {
          return value;
        }
      }
    }

    if (value instanceof Decimal && fieldType == Schema.DisplayType.INTEGER) {
      return ((Decimal) value).intValue();
    }

    return value;
  }
}
