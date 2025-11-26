import * as React from 'react';
import { JSX } from 'react';
import { Task, ViewMode } from "gantt-task-react";
import { TaskType } from "gantt-task-react/dist/types/public-types";
import { fieldNames } from './constants';
import { FieldHelper } from './fieldHelper';

type DataSet = ComponentFramework.PropertyTypes.DataSet;

export interface IGanttChartComponentProps {
    entityDataset: DataSet;
    defaultTaskType: TaskType;
    taskTypeMap: Record<number, TaskType>;
    isDisabled: boolean;
}

export const GanttChartComponent = React.memo((props: IGanttChartComponentProps): JSX.Element => {

    const [columns, setTasks] = React.useState<Task[]>([]);

    const generateTasks = (items: unknown[], columns: unknown[]): Task[] => {
        const entityTypesAndColors: {
            entityLogicalName: string;
            backgroundColor: string;
            backgroundSelectedColor: string;
            progressColor: string;
            progressSelectedColor: string;
        }[] = [];
        const tasks: Task[] = [];
        // Iterate the records (entities) in the dataset.
        items.forEach((item: unknown) => {
            const record = FieldHelper.getPropertyValue<unknown>(item, 'raw');
            const name = FieldHelper.getFieldValue(columns, record, fieldNames.title);
        });
        return tasks;
    };

    const getTaskType = (taskTypeOption: number): TaskType => {
        let taskType: TaskType = props.defaultTaskType;
        if (taskTypeOption) {
            taskType = props.taskTypeMap[taskTypeOption] || props.defaultTaskType;
        }
        return taskType;
    }

    React.useEffect(() => {
        if (props.entityDataset.loading) { return; }
        const columns = props.entityDataset.columns.map((column) => {
            return {
                name: column.displayName,
                fieldName: column.name,
                minWidth: column.visualSizeFactor,
                key: column.name
            }
        });
        const myItems = props.entityDataset.sortedRecordIds.map((id) => {
            const entity = props.entityDataset.records[id];
            const attributes = props.entityDataset.columns.map((column) => {
                return { [column.name]: entity.getFormattedValue(column.name) }

            });
            return Object.assign({
                key: entity.getRecordId(),
                parentId: (entity.getValue("parentRecord") as ComponentFramework.EntityReference | undefined)?.id.guid,
                raw: entity,
            }, ...attributes);
        }).sort((a, b) => a.parentId < b.parentId ? -1 : a.parentId < b.parentId ? 1 : 0);
        setTasks(generateTasks(myItems, columns));
    }, [props.entityDataset]);
    return (
        <div>Gantt Chart Component</div>
    );
});

