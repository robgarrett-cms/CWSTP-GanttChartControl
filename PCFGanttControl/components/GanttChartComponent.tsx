import * as React from "react";
import {
    Gantt,
    Task,
    EventOption,
    StylingOption,
    ViewMode,
    DisplayOption,
} from "gantt-task-react";
import { createHeaderLocal } from "./TaskListHeader";
import { ViewSwitcher } from "./ViewSwitcher";
import { IInputs } from "../generated/ManifestTypes";
import { createTooltip } from "./GanttChartTooltip";
import { createTaskListLocal } from "./TaskListTable";

export type GanttChartComponentProps = {
    context: ComponentFramework.Context<IInputs>;
    tasks: Task[];
    locale: string;
    recordDisplayName: string;
    startDisplayName: string;
    endDisplayName: string;
    progressDisplayName: string;
    startFieldName: string;
    endFieldName: string;
    progressFieldName: string;
    includeTime: boolean;
    isProgressing: boolean;
    crmUserTimeOffset: number;
    fontSize: string;
    ganttHeight?: number;
    rowHeight: number;
    headerHeight: number;
    listCellWidth: string;
    columnWidthQuarter: number;
    columnWidthHalf: number;
    columnWidthDay: number;
    columnWidthWeek: number;
    columnWidthMonth: number;
    onViewChange: (viewMode: ViewMode) => void;
    onExpanderStateChange: (itemId: string, expanderState: boolean) => void;
} & EventOption & DisplayOption;

export const GanttChartComponent: React.FunctionComponent<GanttChartComponentProps> = (props) => {
    const [view, setView] = React.useState(props.viewMode);
    const { context } = props;
    // Events
    const handleDateChange = async (task: Task) => {
        const record = context.parameters.entityDataSet.records[task.id];
        if (!record) { return false; }
        let resultState = true;
        const newStartTime = new Date(task.start.getTime() - props.crmUserTimeOffset * 60000);
        const newEndTime = new Date(task.end.getTime() - props.crmUserTimeOffset * 60000);
        try { 
            const startTimeColumn = context.parameters.entityDataSet.columns.find((c) => c.alias == props.startFieldName);
            const endTimeColumn = context.parameters.entityDataSet.columns.find((c) => c.alias == props.endFieldName);
            // @ts-expect-error("setValue may not exist in current version of ComponentFrameword.d.ts")
            record.setValue(startTimeColumn.name, newStartTime);
            // @ts-expect-error("setValue may not exist in current version of ComponentFrameword.d.ts")
            record.setValue(endTimeColumn.name, newEndTime);
            // @ts-expect-error("save may not exist in current version of ComponentFrameword.d.ts")
            await record.save(record);  
        } catch (e) {
            console.error(e);
            resultState = false;
        }
        context.parameters.entityDataSet.refresh();
        return resultState;
    };

    const handleProgressChange = async (task: Task) => {
        const record = context.parameters.entityDataSet.records[task.id];
        if (!record) { return false; }
        let resultState = true;
        try {
            const progressColumn = context.parameters.entityDataSet.columns.find((c) => c.alias == props.progressFieldName);
            // @ts-expect-error("setValue may not exist in current version of ComponentFrameword.d.ts")
            record.setValue(progressColumn.name, task.progress);
            // @ts-expect-error("save may not exist in current version of ComponentFrameword.d.ts")
            await record.save(record);  
        } catch (e) {
            console.error(e);
            resultState = false;
        }
        context.parameters.entityDataSet.refresh();
        return resultState;
    };

    const handleOpenRecord = async (task: Task) => {
        const recordRef = context.parameters.entityDataSet.records[task.id].getNamedReference();
        context.parameters.entityDataSet.openDatasetItem(recordRef);
    };

    const handleSelect = (task: Task, isSelected: boolean) => {
        if (isSelected) {
            context.parameters.entityDataSet.setSelectedRecordIds([task.id]);
        } else {
            context.parameters.entityDataSet.clearSelectedRecordIds();
        }
    };

    const handleExpanderClick = (task: Task) => {
        props.onExpanderStateChange(task.id, !!task.hideChildren);
    };

    // Styling
    const formatDateShort = (value: Date, includeTime?: boolean) => {
        return context.formatting.formatDateShort(value, includeTime);
    };

    const options: StylingOption & EventOption = {
        fontSize: props.fontSize,
        fontFamily: "SegoeUI, Segoe UI",
        headerHeight: props.headerHeight,
        rowHeight: props.rowHeight,
        barCornerRadius: 0,
        listCellWidth: props.listCellWidth,
        TaskListHeader: createHeaderLocal(
            props.recordDisplayName,
            props.startDisplayName,
            props.endDisplayName
        ),
        TooltipContent: createTooltip(
            props.startDisplayName,
            props.endDisplayName,
            props.progressDisplayName,
            context.resources.getString("Duration"),
            context.resources.getString("Duration_Metric"),
            props.includeTime,
            formatDateShort
        ),
        TaskListTable: createTaskListLocal(
            props.includeTime,
            handleOpenRecord,
            formatDateShort
        ),
    };

    switch (view) {
        case ViewMode.Month:
            options.columnWidth = props.columnWidthMonth;
            break;
        case ViewMode.Week:
            options.columnWidth = props.columnWidthWeek;
            break;
        case ViewMode.Day:
            options.columnWidth = props.columnWidthDay;
            break;
        case ViewMode.HalfDay:
            options.columnWidth = props.columnWidthHalf;
            break;
        default:
            options.columnWidth = props.columnWidthQuarter;
    }

    if (props.isProgressing) {
        options.onProgressChange = handleProgressChange;
    }

    return (
        <div className="Gantt-Wrapper">
            <ViewSwitcher
                context={context}
                onViewChange={(viewMode) => {
                    props.onViewChange(viewMode);
                    setView(viewMode);
                }}
            />
            <Gantt
                {...props}
                {...options}
                viewMode={view}
                onDoubleClick={handleOpenRecord}
                onDateChange={handleDateChange}
                onSelect={handleSelect}
                onExpanderClick={handleExpanderClick}
            />
        </div>
    );
};