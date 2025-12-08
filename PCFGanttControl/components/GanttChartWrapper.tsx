import * as React from 'react';
import { JSX } from 'react';
import { Task, ViewMode } from "gantt-task-react";
import { TaskType } from "gantt-task-react/dist/types/public-types";
import { fieldNames } from '../constants';
import { Xrm } from '../xrm';
import { generate } from '@ant-design/colors';
import { IInputs } from '../generated/ManifestTypes';
import { GanttChartComponent } from './GanttChartComponent';
import { taskHelper } from '../taskHelper';

type EntityRecord = ComponentFramework.PropertyHelper.DataSetApi.EntityRecord;

export interface IGanttChartWrapperProps {
    userTimeOffset: number;
    container: HTMLDivElement;
    viewMode: ViewMode;
    getContext: () => ComponentFramework.Context<IInputs>;
}

interface ColorTheme {
    entityLogicalName: string;
    backgroundColor: string;
    backgroundSelectedColor: string;
    progressColor: string;
    progressSelectedColor: string;
}

interface StateData {
    tasks: Task[];
    projectsExpanderState: Record<string, boolean>;
    viewMode?: ViewMode;
    localeCode: string;
    startFieldName: string;
    endFieldName: string;
    progressFieldName: string;
    recordDisplayName: string;
    startDisplayName: string;
    endDisplayName: string;
    progressDisplayName: string;
    ganttHeight?: number;
    isProgressing: boolean;
}

export const GanttChartWrapper = React.memo((props: IGanttChartWrapperProps): JSX.Element => {
    // State
    const [stateData, setStateData] = React.useState<StateData>();
    const [loading, setLoading] = React.useState(true);
    const [error, setError] = React.useState<string | null>(null);
    // Non-persistent storage.
    const taskTypeMap: Record<number, TaskType> = { 1: "task", 2: "milestone", 3: "project" };
    const defaultTaskType: TaskType = "task";
    const context = props.getContext();
    const entityDataset = context.parameters.entityDataSet;

    const generateTasksAsync = async (
        items: unknown[],
        getExpanderState: () => Record<string, boolean>,
        saveExpanderState: (expanderState: Record<string, boolean>) => void): Promise<Task[]> => {
        const entityTypesAndColors: ColorTheme[] = [];
        const projectsExpanderState: Record<string, boolean> = { ...getExpanderState() };
        const tasks: Task[] = [];
        // Iterate the records (entities) in the dataset.
        for (const item of items) {
            const record = (item as Record<string, unknown>).raw as EntityRecord;
            const name = record?.getValue(fieldNames.title) as string
            const start = record?.getValue(fieldNames.startTime) as string;
            const end = record?.getValue(fieldNames.endTime) as string;
            // We require at least name, start, and end to create a task.
            if (!name || !start || !end) continue;
            const progress = record?.getValue(fieldNames.progress) as number || 0;
            const taskTypeOption = record?.getValue(fieldNames.taskType) as number | undefined;
            const parentRecord = record?.getValue(fieldNames.parentRecord) as ComponentFramework.EntityReference | 0;
            const colorText = record?.getValue(fieldNames.displayColorText) as string;
            const colorOption = record?.getValue(fieldNames.displayColorOption) as string;
            const taskType = getTaskType(taskTypeOption);
            const optionColumn = entityDataset.columns.find((c) => c.alias == fieldNames.displayColorOption);
            const optionLogicalName = optionColumn ? optionColumn.name : "";
            // Get the logical name of the entity to which the record belongs.
            const entRef = record.getNamedReference();
            const entityLogicalName = entRef.etn || "";
            let entityColorTheme = entityTypesAndColors.find((e) => e.entityLogicalName === entityLogicalName);
            // If we didn't get the color theme from the cache, generate it.
            if (!entityColorTheme || colorText || optionLogicalName) {
                entityColorTheme = await generateColorThemeAsync(entityLogicalName,
                    colorText,
                    colorOption,
                    optionLogicalName);
                entityTypesAndColors.push(entityColorTheme);
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
                    isDisabled: (context.parameters.displayMode.raw === "readonly"),
                    styles: { ...entityColorTheme },
                };
                if (taskType === "project") {
                    // Look for the project in the expander state map
                    const expanderState = projectsExpanderState[taskId];
                    if (!expanderState) {
                        // Didn't find the project, set default to expanded
                        projectsExpanderState[taskId] = false;
                        task.hideChildren = false;
                    } else {
                        // Set the project expand/collapse state from the map
                        task.hideChildren = projectsExpanderState[taskId];
                    }
                }
                if (parentRecord) {
                    // Determine if the parent is a project or a task 
                    // and thus if the current entity is a dependant task or child task
                    const parentRecordId = parentRecord.id.guid;
                    const parentRecordRef = entityDataset.records[parentRecordId];
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
        }
        saveExpanderState(projectsExpanderState);
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
        const height = Number(context.mode.allocatedHeight) || -1
        if (height === -1 && !colorText) {
            if (optionValue) {
                // Get by color by OptionSet Color
                const result = await context.utils.getEntityMetadata(entName, [optionLogicalName]);
                const attributes: Xrm.EntityMetadata.AttributesCollection = result["Attributes"] as Xrm.EntityMetadata.AttributesCollection;
                const optionMetadata = attributes.getByName(optionLogicalName);
                entityColor = optionMetadata.attributeDescriptor.OptionSet.find((o) => o.Value === +optionValue)?.Color ?? entityColor;
            } else {
                // Get by Entity Color
                const result = await context.utils.getEntityMetadata(entName, ["EntityColor"]);
                entityColor = result["EntityColor"] as string;
            }
        } else if (colorText) {
            // Get color by hex text value
            entityColor = colorText;
        }
        // Use a pallette generator to create the color theme.
        const colors = generate(entityColor);
        const backgroundColor = context.parameters.customBackgroundColor.raw || colors[2];
        const backgroundSelectedColor = context.parameters.customBackgroundSelectedColor.raw || colors[3];
        const progressColor = context.parameters.customProgressColor.raw || colors[4];
        const progressSelectedColor = context.parameters.customProgressSelectedColor.raw || colors[5];

        return {
            entityLogicalName: entName,
            backgroundColor: backgroundColor,
            backgroundSelectedColor: backgroundSelectedColor,
            progressColor: progressColor,
            progressSelectedColor: progressSelectedColor,
        };
    }

    const getLocaleCodeAsync = async () => {
        // try {
        //     const languages = await context.webAPI.retrieveMultipleRecords(
        //         "languagelocale",
        //         `?$select=code&$filter=localeid eq ${context.userSettings.languageId}`
        //     );
        //     if (languages.entities.length > 0) {
        //         const code = languages.entities[0].code;
        //         return code;
        //     }
        // } catch (e) {
        //     console.error(e);
        // }

        return "en"; // English
    };

    const handleViewModeChange = (viewMode: ViewMode) => {
        const stateBag = stateData;
        if (stateBag) {
            stateBag.viewMode = viewMode;
            setStateData(stateBag);
        }
    }

    const handleExpanderStateChange = (itemId: string, expanderState: boolean) => {
        const stateBag = stateData;
        if (stateBag) {
            stateBag.projectsExpanderState[itemId] = expanderState;
            setStateData(stateBag);
            entityDataset.refresh();
        }
    }

    React.useEffect(() => {
        // Nothing to do if the dataset hasn't loaded.
        if (entityDataset.loading) return;
        if (!entityDataset.sortedRecordIds || entityDataset.sortedRecordIds.length === 0) return;

        // Avoid state updates if unmounted
        let isMounted = true;

        const fetchTasks = async () => {
            setLoading(true);
            setError(null);
            try {
                // Initialize state bag.
                const stateBag: StateData = {
                    tasks: [],
                    projectsExpanderState: {},
                    viewMode: props.viewMode,
                    localeCode: "en",
                    startFieldName: "",
                    endFieldName: "",
                    progressFieldName: "",
                    recordDisplayName: "",
                    startDisplayName: "",
                    endDisplayName: "",
                    progressDisplayName: "",
                    ganttHeight: undefined,
                    isProgressing: false,
                    ...(stateData || {}),
                };

                // Get the columns
                const columns = entityDataset.columns.sort((column1, column2) => column1.order - column2.order).map((column) => {
                    return {
                        name: column.displayName,
                        fieldName: column.name,
                        minWidth: column.visualSizeFactor,
                        key: column.name
                    }
                });
                const nameField = columns.find((c) => c.name === fieldNames.title)!;
                const startField = columns.find((c) => c.name === fieldNames.startTime)!;
                const endField = columns.find((c) => c.name === fieldNames.endTime)!;
                const progressField = columns.find((c) => c.name === fieldNames.progress);

                // Get the items from the dataset.
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

                // Generate the tasks from the items.
                const unorderedTasks = await generateTasksAsync(myItems, 
                    () => { return stateBag.projectsExpanderState; }, 
                    (expanderState) => { stateBag.projectsExpanderState = expanderState });
                stateBag.tasks = taskHelper.reorderTasks(unorderedTasks);
                // Get the locale code.
                stateBag.localeCode = await getLocaleCodeAsync();
                // Field names.
                stateBag.startFieldName = startField.name;
                stateBag.endFieldName = endField.name;
                stateBag.progressFieldName = progressField ? progressField.name : "";
                stateBag.isProgressing = !!progressField;
                // Header Display names.
                stateBag.recordDisplayName = context.parameters.customHeaderDisplayName.raw || nameField.name;
                stateBag.startDisplayName = context.parameters.customHeaderStartName.raw || startField.name;
                stateBag.endDisplayName = context.parameters.customHeaderEndName.raw || endField.name;
                stateBag.progressDisplayName = context.parameters.customHeaderProgressName.raw || (progressField ? progressField.name : "");
                // Height of chart.
                if (context.mode.allocatedHeight !== -1) {
                    stateBag.ganttHeight = context.mode.allocatedHeight - 15;
                } else if (context.parameters.isSubgrid.raw === "no") {
                    stateBag.ganttHeight = props.container.offsetHeight - 100;
                }

                // Update the state data.
                if (isMounted) setStateData(stateBag);

            } catch (e) {
                if (isMounted) setError("Failed to load Gantt chart data");
            } finally {
                if (isMounted) setLoading(false);
            }
        }
        fetchTasks();
        return () => { isMounted = false; };
    }, [entityDataset.loading, entityDataset.sortedRecordIds]);

    const render = () => {
        if (error) {
            return <div className="error-message">{error}</div>
        } else if (!loading && stateData) {
            return <div className='myTestClass'>
                <div>Gantt Chart Component v1.3</div>
                {/* <div>{JSON.stringify(stateData.tasks)}</div> */}
                <GanttChartComponent
                    context={context}
                    tasks={stateData.tasks}
                    locale={stateData.localeCode}
                    recordDisplayName={stateData.recordDisplayName}
                    startDisplayName={stateData.startDisplayName}
                    endDisplayName={stateData.endDisplayName}
                    progressDisplayName={stateData.progressDisplayName}
                    startFieldName={stateData.startFieldName}
                    endFieldName={stateData.endFieldName}
                    progressFieldName={stateData.progressFieldName}
                    isProgressing={stateData.isProgressing}
                    viewMode={stateData.viewMode}
                    rtl={context.userSettings.isRTL}
                    timeStep={context.parameters.timeStep.raw || 15}
                    includeTime={context.parameters.displayDateFormat.raw === "datetime"}
                    crmUserTimeOffset={props.userTimeOffset}
                    ganttHeight={stateData.ganttHeight}
                    fontSize={context.parameters.fontSize.raw || "14px"}
                    rowHeight={context.parameters.rowHeight.raw ? context.parameters.rowHeight.raw : 50}
                    headerHeight={context.parameters.headerHeight.raw ? context.parameters.headerHeight.raw : 50}
                    listCellWidth={(context.parameters.listCellWidth.raw ? `${context.parameters.listCellWidth.raw}px` : "")}
                    columnWidthQuarter={context.parameters.columnWidthQuarter.raw || 0}
                    columnWidthHalf={context.parameters.columnWidthHalf.raw || 0}
                    columnWidthDay={context.parameters.columnWidthDay.raw || 0}
                    columnWidthWeek={context.parameters.columnWidthWeek.raw || 0}
                    columnWidthMonth={context.parameters.columnWidthMonth.raw || 0}
                    onViewChange={handleViewModeChange}
                    onExpanderStateChange={handleExpanderStateChange} />
            </div>
        } else {
            return <div className="loading-indicator">Loading Gantt Chart...</div>
        }
    }

    return render();
});

