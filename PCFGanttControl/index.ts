/* eslint-disable */
import { IInputs, IOutputs } from "./generated/ManifestTypes";
import { generate } from "@ant-design/colors";
import { Task, ViewMode } from "gantt-task-react";
import { TaskType } from "gantt-task-react/dist/types/public-types";
import DataSetInterfaces = ComponentFramework.PropertyHelper.DataSetApi;
import { Xrm } from "./xrm";
import { GanttChartComponent, IGanttChartComponentProps } from "./GanttControl";
import * as React from "react";

type DataSet = ComponentFramework.PropertyTypes.DataSet;

export class PCFGanttControl implements ComponentFramework.ReactControl<IInputs, IOutputs> {

    private _container: ComponentFramework.ReactControl<IInputs, IOutputs>;
    private _crmUserTimeOffset: number;
    private _viewMode: ViewMode;
    private _dataSet: DataSet;
    private _displayNameStr = "title";
    private _scheduledStartStr = "startTime";
    private _scheduledEndStr = "endTime";
    private _progressStr = "progress";
    private _taskTypeOption = "taskTypeOption";
    private _parentRecordStr = "parentRecord";
    private _displayColorText = "displayColorText";
    private _displayColorOption = "displayColorOption";
    private _defaultEntityColor = "#2975B2";
    private _projects: Record<string, boolean>;
    private _defaultTaskType: TaskType = "task";
    private _taskTypeMap: Record<number, TaskType> = { 1: "task", 2: "milestone", 3: "project" };

    /**
     * Empty constructor.
     */
    constructor() {
        // Empty
    }

    /**
     * Used to initialize the control instance. Controls can kick off remote server calls and other initialization actions here.
     * Data-set values are not initialized here, use updateView.
     * @param context The entire property bag available to control via Context Object; It contains values as set up by the customizer mapped to property names defined in the manifest, as well as utility functions.
     * @param notifyOutputChanged A callback method to alert the framework that the control has new outputs ready to be retrieved asynchronously.
     * @param state A piece of data that persists in one session for a single user. Can be set at any point in a controls life cycle by calling 'setControlState' in the Mode interface.
     */
    public init(
        context: ComponentFramework.Context<IInputs>,
        notifyOutputChanged: () => void,
        state: ComponentFramework.Dictionary
    ): void {
        this._viewMode = context.parameters.viewMode.raw as ViewMode;
        this._crmUserTimeOffset =
            context.userSettings.getTimeZoneOffsetMinutes(new Date()) +
            new Date().getTimezoneOffset();
        this._projects = {};
        context.parameters.entityDataSet.paging.setPageSize(5000);
        context.parameters.entityDataSet.refresh();
    }


    /**
     * Called when any value in the property bag has changed. This includes field values, data-sets, global values such as container height and width, offline status, control metadata values such as label, visible, etc.
     * @param context The entire property bag available to control via Context Object; It contains values as set up by the customizer mapped to names defined in the manifest, as well as utility functions
     * @returns ReactElement root react element for the control
     */
    public updateView(context: ComponentFramework.Context<IInputs>): React.ReactElement {
        // this._dataSet = context.parameters.entityDataSet;
        // this.updateViewAsync(context).catch(error => { console.error("updateViewAsync failed:", error); }).then(() => {
            
        //     // Clear previous content
        //     this._container.innerHTML = "";

        //     // Create a simple element
        //     const message = document.createElement("div");
        //     message.innerText = "This is a placeholder (v0.1.0)";
        //     message.style.padding = "10px";
        //     message.style.backgroundColor = "#eef";
        //     message.style.border = "1px solid #99c";

        //     // Append to container
        //     this._container.appendChild(message);
        // });
         const props: IGanttChartComponentProps = { 
            entityDataset: context.parameters.entityDataSet
        };
        return React.createElement(GanttChartComponent, props);
    }

    /**
         * It is called by the framework prior to a control receiving new data.
         * @returns an object based on nomenclature defined in manifest, expecting object[s] for property marked as "bound" or "output"
         */
    public getOutputs(): IOutputs {
        return {};
    }

    /**
     * Called when the control is to be removed from the DOM tree. Controls should use this call for cleanup.
     * i.e. cancelling any pending remote calls, removing listeners, etc.
     */
    public destroy(): void {
        // Add code to cleanup control if necessary
    }

    private updateViewAsync = async (context: ComponentFramework.Context<IInputs>) => {
        this._dataSet = context.parameters.entityDataSet;
        // Get the columns from the dataset
        const columns = this._dataSet.columns;
        const nameField = columns.find((c) => c.alias === this._displayNameStr);
        const startField = columns.find((c) => c.alias === this._scheduledStartStr);
        const endField = columns.find((c) => c.alias === this._scheduledEndStr);
        const progressField = columns.find((c) => c.alias === this._progressStr);
        if (!nameField || !startField || !endField || !context.parameters.timeStep.raw) return;
        try {
            const tasks = await this.generateTasks(
                context,
                this._dataSet,
                !!progressField
            );
        } catch (e) {
            console.error(e);
        }
    };

    private generateTasks = async (
        context: ComponentFramework.Context<IInputs>,
        dataset: ComponentFramework.PropertyTypes.DataSet,
        isProgressing: boolean
    ) => {
        const entityTypesAndColors: {
            entityLogicalName: string;
            backgroundColor: string;
            backgroundSelectedColor: string;
            progressColor: string;
            progressSelectedColor: string;
        }[] = [];
        const isDisabled = context.parameters.displayMode.raw === "readonly";
        const tasks: Task[] = [];

        // Iterate the records (entities) in the dataset.
        dataset.sortedRecordIds.forEach(recordId => {
            const record = dataset.records[recordId];
            const name = record.getValue(this._displayNameStr) as string;
            const start = record.getValue(this._scheduledStartStr) as string;
            const end = record.getValue(this._scheduledEndStr) as string;
            const taskTypeOption = Number(record.getValue(this._taskTypeOption));
            const parentRecord = record.getValue(this._parentRecordStr) as ComponentFramework.EntityReference;
            const progress = isProgressing ? Number(record.getValue(this._progressStr)) : 0;
            const colorText = record.getValue(this._displayColorText) as string;
            const optionValue = record.getValue(this._displayColorOption) as string;
            const optionColumn = dataset.columns.find((c) => c.alias == this._displayColorOption);
            const optionLogicalName = optionColumn ? optionColumn.name : "";
            const taskType = this.getTaskType(taskTypeOption);

            // Get the entity logical name from the record
            const entRef = record.getNamedReference();
            const entName = entRef.etn || (<any>entRef).logicalName as string;

            // Get the entity color theme using the logical name from the cache.
            let entityColorTheme = entityTypesAndColors.find((e) => e.entityLogicalName === entName);

            // If we didn't get the color theme from the cache, generate it.
            // if (!entityColorTheme || colorText || optionLogicalName) {
            //     entityColorTheme = await this.generateColorTheme(
            //         context,
            //         entName,
            //         colorText,
            //         optionValue,
            //         optionLogicalName
            //     );
            //     entityTypesAndColors.push(entityColorTheme);
            // }

            // We require at least name, start, and end to create a task.
            if (!name || !start || !end) return;
            try {
                const taskId = record.getRecordId();
                const task: Task = {
                    id: taskId,
                    name,
                    // Start and End times are offsets from UTC in milliseconds.
                    start: new Date(new Date(start).getTime() + this._crmUserTimeOffset * 60000),
                    end: new Date(new Date(end).getTime() + this._crmUserTimeOffset * 60000),
                    progress: progress,
                    type: taskType,
                    isDisabled: isDisabled,
                    styles: { ...entityColorTheme },
                };

                // if (taskType === "project") {
                //     // Look for the project in the expander state map
                //     const expanderState = this._projects[taskId];
                //     if (!expanderState) {
                //         // Didn't find the project, set default to expanded
                //         this._projects[taskId] = false;
                //         task.hideChildren = false;
                //     } else {
                //         // Set the project expand/collapse state from the map
                //         task.hideChildren = this._projects[taskId];
                //     }
                // }
                if (parentRecord) {
                    // Determine if the parent is a project or a task 
                    // and thus if the current entity is a dependant task or child task
                    const parentRecordId = parentRecord.id.guid;
                    const parentRecordRef = dataset.records[parentRecordId];
                    if (parentRecordRef) {
                        // const parentType = this.getTaskType(
                        //     (parentRecordRef.getValue(this._taskTypeOption) as string),
                        //     context.parameters.taskTypeMapping.raw
                        // );
                        // if (parentType === "project") {
                        //     task.project = parentRecordId;
                        // } else {
                        //     task.dependencies = [parentRecordId];
                        // }
                    }
                }
                tasks.push(task);
            } catch (e) {
                throw new Error(
                    `Create task error. Record id: ${record.getRecordId()}, name: ${name}, start time: ${start}, end time: ${end}, progress: ${progress}. Error text ${e}`
                );
            }
        });
        return tasks;
    }

    private getTaskType = (taskTypeOption: number): TaskType => {
        let taskType: TaskType = this._defaultTaskType;
        if (taskTypeOption) {
            taskType = this._taskTypeMap[taskTypeOption] || this._defaultTaskType;
        }
        return taskType;
    }
}
