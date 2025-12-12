import { Task } from "gantt-task-react";
import { TaskType } from "gantt-task-react/dist/types/public-types";

export class taskHelper {

    static isDependent = (task: Task, tasks: Task[]): boolean => {
        if (task.project) return true;
        // Iterate the tasks and find those where task is a dependent.
        return tasks.some(t => t.dependencies?.includes(task.id));
    }

    static reorderTasks = (tasks: Task[]): Task[] => {
        const sortedResults: Task[] = [];

        interface ProjectGroup {
            project: Task;
            children: Task[];
        }

        const groupTasksByProject = (tasks: Task[]): ProjectGroup[] => {
            const projects = tasks.filter(t => tasks.some(c => c.project === t.id));
            return projects.map(p => {
                // Direct children of the project
                const directChildren = tasks.filter(c => c.project === p.id);
                // Tasks that depend on any of the project’s children
                const dependents = tasks.filter(c =>
                    c.dependencies?.some(depId =>
                        directChildren.some(child => child.id === depId)
                    )
                );
                // Merge children + dependents, avoiding duplicates
                const children = [...directChildren, ...dependents.filter(d => !directChildren.includes(d))];
                return {
                    project: p,
                    children
                };
            });
        }

        const sortChildTasks = (children: Task[]): Task[] => {
            return children.sort((first, second) => {
                if (first.end <= second.start) return -1; // First ends before second starts.
                if (second.end <= first.start) return 1; // Second ends before firest starts.
                // Overlap tasks, check start dates.
                return first.start.getTime() - second.start.getTime();
            });
        }
        // Sort children of each group.
        const grouped = groupTasksByProject(tasks).sort((p1, p2) => p1.project.start.getTime() - p2.project.start.getTime());
        // Flatten structure.
        grouped.forEach((g: ProjectGroup) => {
            sortedResults.push(g.project);
            sortedResults.push(...sortChildTasks(g.children));
        });
        return sortedResults;
    }
}