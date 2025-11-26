interface HasGetValue {
  getValue: (what: string) => unknown;
}

export class FieldHelper {

  public static getFieldValue = <T = unknown>(columns: unknown[], record: unknown, fieldName: string): T | undefined => {
    const titleFieldName = FieldHelper.getLogicalFieldName(columns, fieldName);
    return FieldHelper.tryGetValue(record, titleFieldName) as T | undefined;
  }

  public static getLogicalFieldName = (columns: unknown[], displayName: string): string | undefined => {
    const column = columns.find((col: unknown) => FieldHelper.getPropertyValue<string>(col, 'name') === displayName);
    return column ? FieldHelper.getPropertyValue<string>(column, 'fieldName') : undefined;
  }

  public static getPropertyValue = <T = unknown>(object: unknown, propertyName: string): T | undefined => {
    if (typeof object === 'object' && object !== null && propertyName in object) {
      return (object as Record<string, unknown>)[propertyName] as T;
    }
    return undefined;
  };

  static hasGetValue(obj: unknown): obj is HasGetValue {
    return (
      typeof obj === "object" &&
      obj !== null &&
      "getValue" in obj &&
      typeof (obj as { getValue: unknown }).getValue === "function"
    );
  }

  static tryGetValue(obj: unknown, what: string | undefined): unknown {
    if (what === undefined) { return undefined; }
    if (FieldHelper.hasGetValue(obj)) {
      return obj.getValue(what);
    }
    return undefined;
  }
}