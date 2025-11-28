import * as React from 'react';
import { JSX } from 'react';
import { Task, ViewMode } from "gantt-task-react";
import { TaskType } from "gantt-task-react/dist/types/public-types";
import { fieldNames } from './constants';
import { Xrm } from './xrm';
import { generate } from '@ant-design/colors';

type DataSet = ComponentFramework.PropertyTypes.DataSet;
type EntityRecord = ComponentFramework.PropertyHelper.DataSetApi.EntityRecord;
type NullableString = string | null;

export interface IGanttChartComponentProps {
    entityDataset: DataSet;
    userTimeOffset: number;
    isDisabled: boolean;
    customBackgroundColor: NullableString;
    customBackgroundSelectedColor: NullableString;
    customProgressColor: NullableString;
    customProgressSelectedColor: NullableString;
    allocatedHeight: number;
    viewMode: string;
    // Dataset callback for metadata retrieval
    getDatasetMetadata: (entityName: string, columns: string[]) => Promise<Record<string, unknown>>;
}

interface ColorTheme {
    entityLogicalName: string;
    backgroundColor: string;
    backgroundSelectedColor: string;
    progressColor: string;
    progressSelectedColor: string;
}

export const GanttChartComponent = React.memo((props: IGanttChartComponentProps): JSX.Element => {

    const [cachedTasks, setCachedTasks] = React.useState<Task[]>([]);
    const [cachedProjects, setCachedProjects] = React.useState<Record<string, boolean>>({});
    const taskTypeMap: Record<number, TaskType> = { 1: "task", 2: "milestone", 3: "project" };
    const defaultTaskType: TaskType = "task";

    const generateTasks = (items: unknown[]): Task[] => {
        const entityTypesAndColors: ColorTheme[] = [];
        const tasks: Task[] = [];
        const projects: Record<string, boolean> = { ...cachedProjects };
        // Iterate the records (entities) in the dataset.
        items.forEach((item: unknown) => {
            const record = (item as Record<string, unknown>).raw as EntityRecord;
            const name = record?.getValue(fieldNames.title) as string
            const start = record?.getValue(fieldNames.startTime) as string;
            const end = record?.getValue(fieldNames.endTime) as string;
            // We require at least name, start, and end to create a task.
            if (!name || !start || !end) return;
            const progress = record?.getValue(fieldNames.progress) as number || 0;
            const taskTypeOption = record?.getValue(fieldNames.taskType) as number | undefined;
            const parentRecord = record?.getValue(fieldNames.parentRecord) as ComponentFramework.EntityReference | 0;
            const colorText = record?.getValue(fieldNames.displayColorText) as string;
            const colorOption = record?.getValue(fieldNames.displayColorOption) as string;
            const taskType = getTaskType(taskTypeOption);
            const optionColumn = props.entityDataset.columns.find((c) => c.alias == fieldNames.displayColorOption);
            const optionLogicalName = optionColumn ? optionColumn.name : "";
            // Get the logical name of the entity to which the record belongs.
            const entRef = record.getNamedReference();
            const entityLogicalName = entRef.etn || "";
            let entityColorTheme = entityTypesAndColors.find((e) => e.entityLogicalName === entityLogicalName);
            // If we didn't get the color theme from the cache, generate it.
            if (!entityColorTheme || colorText || optionLogicalName) {
                generateColorThemeAsync(
                    entityLogicalName,
                    colorText,
                    colorOption,
                    optionLogicalName
                ).then((colorTheme) => {
                    entityTypesAndColors.push(colorTheme);
                    entityColorTheme = colorTheme;
                    return colorTheme
                }).catch((e) => {
                    console.error(`Error generating color theme for entity ${entityLogicalName}. Error text: ${e}`);
                    throw e;
                });
            }
            try {
                const taskId = record.getRecordId();
                const task: Task = {
                    id: taskId,
                    name,
                    // Start and End times are offsets from UTC in milliseconds.
                    start: new Date(new Date(start).getTime() + props.userTimeOffset * 60000),
                    end: new Date(new Date(end).getTime() + props.userTimeOffset * 60000),
                    progress: progress,
                    type: taskType,
                    isDisabled: props.isDisabled,
                    styles: { ...entityColorTheme },
                };
                if (taskType === "project") {
                    // Look for the project in the expander state map
                    const expanderState = projects[taskId];
                    if (!expanderState) {
                        // Didn't find the project, set default to expanded
                        projects[taskId] = false;
                        task.hideChildren = false;
                    } else {
                        // Set the project expand/collapse state from the map
                        task.hideChildren = projects[taskId];
                    }
                }
                if (parentRecord) {
                    // Determine if the parent is a project or a task 
                    // and thus if the current entity is a dependant task or child task
                    const parentRecordId = parentRecord.id.guid;
                    const parentRecordRef = props.entityDataset.records[parentRecordId];
                    if (parentRecordRef) {
                        const parentTypeOption = parentRecordRef.getValue(fieldNames.taskType) as number | undefined;
                        const parentType = getTaskType(parentTypeOption);
                        if (parentType === "project") {
                            task.project = parentRecordId;
                        } else {
                            task.dependencies = [parentRecordId];
                        }
                    }
                }
                tasks.push(task);
            } catch (e) {
                throw new Error(
                    `Create task error. Record id: ${record.getRecordId()}, name: ${name}, start time: ${start}, end time: ${end}, progress: ${progress}. Error text ${e}`
                );
            } 
        });
        setCachedProjects(projects);
        return tasks;
    };

    const getTaskType = (taskTypeOption: number | undefined): TaskType => {
        let taskType: TaskType = defaultTaskType;
        if (taskTypeOption) {
            taskType = taskTypeMap[taskTypeOption] || defaultTaskType;
        }
        return taskType;
    }

    const generateColorThemeAsync = async (
        entName: string,
        colorText: string,
        optionValue: string,
        optionLogicalName: string
    ): Promise<ColorTheme> => {
        let entityColor = fieldNames.defaultEntityColor;
        // Model App
        const height = props.allocatedHeight
        if (height === -1 && !colorText) {
            if (optionValue) {
                // Get by color by OptionSet Color
                const result = await props.getDatasetMetadata(entName, [optionLogicalName]);
                const attributes: Xrm.EntityMetadata.AttributesCollection = result["Attributes"] as Xrm.EntityMetadata.AttributesCollection;
                const optionMetadata = attributes.getByName(optionLogicalName);
                entityColor = optionMetadata.attributeDescriptor.OptionSet.find((o) => o.Value === +optionValue)?.Color ?? entityColor;
            } else {
                // Get by Entity Color
                const result = await props.getDatasetMetadata(entName, ["EntityColor"]);
                entityColor = result["EntityColor"] as string;
            }
        } else if (colorText) {
            // Get color by hex text value
            entityColor = colorText;
        }
        // Use a pallette generator to create the color theme.
        const colors = generate(entityColor);
        const backgroundColor = props.customBackgroundColor || colors[2];
        const backgroundSelectedColor = props.customBackgroundSelectedColor || colors[3];
        const progressColor = props.customProgressColor || colors[4];
        const progressSelectedColor = props.customProgressSelectedColor || colors[5];

        return {
            entityLogicalName: entName,
            backgroundColor: backgroundColor,
            backgroundSelectedColor: backgroundSelectedColor,
            progressColor: progressColor,
            progressSelectedColor: progressSelectedColor,
        };
    }

    React.useEffect(() => {
        if (props.entityDataset.loading) { return; }
        // Get the items from the dataset.
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
        // Generate the tasks from the items.
        setCachedTasks(generateTasks(myItems));
    }, [props.entityDataset]);
    return (
        <div>
            <div>Gantt Chart Component</div>
        </div>
    );
});

