# Gantt Chart Component for CMS.

## Build and deploy instructions
1. Install Power Platform Cli tools in Visual Studio Code
2. Open a terminal in VSCode
3. Run `npm i`
4. Run `npm run build` to make sure everything builds.
5. Change directory to the Solution folder.
6. Run `dotnet build -c Release`
7. Deploy the zip file in `bin/Release/` to PowerApps environment.

## Remote debugging
1. Install Power Platform Cli tools in Visual Studio Code
2. Open a terminal in VSCode
3. Run `npm i`
4. Run `pac pcf push` make sure everything builds.
5. Run `node ./serve.js` - this starts an express web server to host the current bundle file.
6. Run a Canvas app with the Gantt Chart displayed.
7. Open developer tools in the browser. **Turn off page caching**.
8. Use Requestly or Fiddler to redirect requests for the bundle.js file to the local instance.
   I used the regex in a redirect: `/.+/PCFControls/cwstp_CMS.CWSTP.PCFGanttControl/.*bundle.js(?:\?.*)?$/`
9. Open the `index.ts` file in the browser devtools sources tab.
10. Add break points, refresh the page to debug.
