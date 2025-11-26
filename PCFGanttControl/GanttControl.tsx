import * as React from 'react';
import { JSX } from 'react';

type DataSet = ComponentFramework.PropertyTypes.DataSet;

export interface IGanttChartComponentProps {
    entityDataset: DataSet;
}

export const GanttChartComponent = React.memo(({ entityDataset }: IGanttChartComponentProps): JSX.Element => {

    const [columns, setColumns] = React.useState<unknown>([]);
    const [items, setItems] = React.useState<unknown[]>([]);

    React.useEffect(() => {
        if (entityDataset.loading) { return; }
        const columns = entityDataset.columns.map((column) => {
            return {
                name: column.displayName,
                fieldName: column.name,
                minWidth: column.visualSizeFactor,
                key: column.name
            }
        });
        setColumns(columns);
        const myItems = entityDataset.sortedRecordIds.map((id) => {
            const entity = entityDataset.records[id];
            const attributes = entityDataset.columns.map((column) => {
                return { [column.name]: entity.getFormattedValue(column.name) }

            });
            return Object.assign({
                key: entity.getRecordId(),
                parentId: (entity.getValue("parentRecord") as ComponentFramework.EntityReference | undefined)?.id.guid,
                raw: entity,
            }, ...attributes);
        }).sort((a, b) => a.parentId < b.parentId ? -1 : a.parentId < b.parentId ? 1 : 0);
        setItems(myItems);
    }, [entityDataset]);
    return (
        <div>Gantt Chart Component</div>
    );
});
