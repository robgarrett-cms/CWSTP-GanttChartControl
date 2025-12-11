import { Task } from "gantt-task-react";

export class taskHelper {

    static isDependent = (task: Task, tasks: Task[]): boolean => {
        if (task.project) return true;
        // Iterate the tasks and find those where task is a dependent.
        return tasks.some(t => t.dependencies?.includes(task.id));
    }

    static reorderTasks = (tasks: Task[]): Task[] => {
        const taskMap = new Map<string, Task>();
        const projectCache = new Map<string, string>(); // Cache for resolved project IDs
        /**
         * Finds the effective root project ID for a task.
         * Logic: Prioritizes the project associated with the dependency that finishes 
         * **latest** (maximum endDate). If no dependencies exist, or if all dependencies 
         * point to the same project, standard parent/root rules apply.
        */
        const findProjectId = (taskId: string, visited = new Set<string>()): string => {
            if (projectCache.has(taskId)) return projectCache.get(taskId)!;

            const task = taskMap.get(taskId);
            if (!task) throw new Error(`Task ${taskId} not found in map.`);

            // Base Case 1: Cycle detection (Crucial for recursive calls)
            if (visited.has(taskId)) throw new Error(`Circular dependency detected involving ${taskId}`);
            visited.add(taskId);

            // Base Case 2: Explicit Parent
            if (task.project) {
                projectCache.set(taskId, task.project);
                return task.project;
            }

            // Inference Case: Look at dependencies to find the latest-finishing project
            if (task.dependencies && task.dependencies.length > 0) {
                let latestEndDate = new Date(0);
                let primaryProjectId = '';

                for (const depId of task.dependencies) {
                    // Recursively find the project ID for the dependency
                    const depProjectId = findProjectId(depId, new Set(visited));

                    // Look up the dependency's provided end date
                    const depTask = taskMap.get(depId);
                    const depEndDate = depTask?.end;

                    // Check if we have a valid end date and if it finishes later than the current latest
                    if (depEndDate && depEndDate.getTime() > latestEndDate.getTime()) {
                        latestEndDate = depEndDate;
                        primaryProjectId = depProjectId;
                    }
                }

                if (primaryProjectId) {
                    projectCache.set(taskId, primaryProjectId);
                    return primaryProjectId;
                }
            }

            // Base Case 3: Root Project (treat its ID as its own project ID)
            projectCache.set(taskId, task.id);
            return task.id;
        };

        /**
         * Performs a standard topological sort (DFS) on a single group of tasks.
         * Ensures local dependencies precede their dependents.
        */
        const sortGroup = (group: Task[]): Task[] => {
            const sorted: Task[] = [];
            const visited = new Set<string>();
            const visiting = new Set<string>();
            const groupIds = new Set(group.map(t => t.id));

            const visit = (t: Task) => {
                if (visited.has(t.id)) return;
                if (visiting.has(t.id)) throw new Error(`Circular dependency in task group ${t.id}`);

                visiting.add(t.id);

                if (t.dependencies) {
                    t.dependencies.forEach((depId) => {
                        // Only process the dependency if it belongs to this specific group
                        if (groupIds.has(depId)) {
                            const depTask = taskMap.get(depId);
                            if (depTask) {
                                visit(depTask);
                            }
                        }
                    });
                }

                visiting.delete(t.id);
                visited.add(t.id);
                sorted.push(t);
            };

            // Separate the root project object from the child tasks
            const rootProject = group.find(t => t.id === findProjectId(t.id) && !t.project);
            const children = group.filter(t => t !== rootProject);

            // Sort all children
            children.forEach(visit);

            // Return the root project followed by the topologically sorted children
            return rootProject ? [rootProject, ...sorted] : sorted;
        };

        /**
         * Adjusts the startDate and endDate of all Project tasks based on their children.
         * @param finalSortedList The list of all tasks, grouped and sorted.
         * @returns The list with updated project dates.
        */
        const adjustProjectDates = (finalSortedList: Task[]): Task[] => {
            // Map to store min/max dates for each project ID
            const projectTimeRanges = new Map<string, { minStart: Date, maxEnd: Date, isProject: boolean }>();

            // 1. Scan all tasks and determine the effective time range for each project
            finalSortedList.forEach(task => {
                const projectId = findProjectId(task.id);

                if (!projectTimeRanges.has(projectId)) {
                    projectTimeRanges.set(projectId, {
                        minStart: new Date(task.start),
                        maxEnd: new Date(task.end),
                        isProject: task.id === projectId && !task.project
                    });
                } else {
                    const range = projectTimeRanges.get(projectId)!;

                    // Update min start date
                    if (task.start.getTime() < range.minStart.getTime()) {
                        range.minStart = new Date(task.start);
                    }
                    // Update max end date
                    if (task.end.getTime() > range.maxEnd.getTime()) {
                        range.maxEnd = new Date(task.end);
                    }
                }
            });

            // 2. Apply the determined ranges back to the root Project tasks
            finalSortedList.forEach(task => {
                const projectId = findProjectId(task.id);
                const range = projectTimeRanges.get(projectId);

                // Only modify the actual Project Root task (id === projectId and no parent)
                if (range && task.id === projectId && !task.project) {
                    task.start = range.minStart;
                    task.end = range.maxEnd;
                }
            });

            return finalSortedList;
        };

        // 1. Initialize maps using the provided, pre-scheduled tasks
        taskMap.clear();
        tasks.forEach(t => taskMap.set(t.id, t));
        projectCache.clear();

        // 2. Group tasks by their resolved Project ID
        const projectGroups = new Map<string, Task[]>();

        tasks.forEach((task) => {
            // Use the date-driven inference logic
            const projectId = findProjectId(task.id);

            if (!projectGroups.has(projectId)) {
                projectGroups.set(projectId, []);
            }
            projectGroups.get(projectId)!.push(task);
        });

        // 3. Process each group, sort it, and flatten into the final array
        let finalResult: Task[] = [];

        // Sort project IDs to maintain a stable, predictable output order (e.g., P1, P2, P3)
        const sortedProjectIds = Array.from(projectGroups.keys()).sort();

        sortedProjectIds.forEach((pid) => {
            const group = projectGroups.get(pid)!;
            const sortedGroup = sortGroup(group);
            finalResult = finalResult.concat(sortedGroup);
        });

        // 4. POST-PROCESSING: Adjust Project Start/End Dates
        return adjustProjectDates(finalResult);
    }
}