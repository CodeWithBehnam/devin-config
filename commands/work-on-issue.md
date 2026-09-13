Please analyze and work on the GitHub issue: $ARGUMENTS.

Follow these steps:

# PLAN
0. Use 'gh issue view' to get the issue details
1. Understand the problem described in the user prompt
2. Ask clarifying questions if necessary
3. Understand the prior art for this request, feature, or issue
    - Search the scratchpads for previous thoughts related to this issue
    - Search PRs to see if you can find history on this issue
    - Search the codebase for relevant files
    - Read the files and find relevant functions, classes, and lines of code
    - Understand the relevant files or code
4. Think harder about how to break the issue down into a series of small, managable tasks
5. Think about how to test the planned changes to ensure that they work
6. Document your plan in a new file in the scratchpad directory
    - Include the issue name in the filename
    - Include a link to the issue in the scratchpad if any exist

# CREATE
1. Create a new branch for the issue
2. Solve the issue in small, managable steps according to your plan
3. Commit your changes after each step
    - Do not mention AI, Devin, or LLMs in your commit messages
    - Do not attribute yourself or provide co-attribution
4. Review that you have made no breaking changes to the existing code before proceeding onto testing

# TEST
1. Use the MCP server interface with tools to test new functionality directly and explicitly
    - You normally do not need to start the server. You can immediately use its tools because it starts when you initialize
    - If you do need to start or reset the server, you should:
        - Kill the process
        - Delete the pycache
        - Restart the server by running `uv run python -m server.py`
2. Find reports for testing
    - Test local reports from the examples directory
    - Find cloud reports in the MCP testing workspace
        - Use the list_workspaces tool to find workspaces
        - Use the list_reports tool to find reports
3. Make a copy of the report that you are testing
4. Perform the planned tests
5. Document test conditions and results concisely in the scratchpad
6. When you encouter an error, stop the test
    - Review and think about the error
    - Investigate the source file
    - Think harder about why the error occurred
    - Make a plan about how to fix the error
    - Apply your fix and re-run the test
7. Provide the user with a link to the copy report that you tested to verify the test and return feedback


# COMMIT
1. Once the user has accepted the test, you can merge the changes into main
2. Add a comment to the issue with a description of the implemented changes
3. Ask the user permission to close the issue