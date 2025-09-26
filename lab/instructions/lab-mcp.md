# Part 1 - Consuming an MCP server

In this lab module, you are going to understand how to extend an agent made with Microsoft Copilot Studio using an MCP (Model Context Protocol) server. Specifically, you are going to consume an existing MCP server that provides tools for managing a hypothetical list of candidates for a job role. The MCP server will offer functionalities to:

- List all candidates 
- Search for candidates by criteria
- Add new candidates 
- Update existing candidate information
- Remove candidates 

In this lab module you will learn:

- How to configure and connect to an existing MCP server
- How to consume MCP tools and resources from an external server
- How to integrate MCP servers with Copilot Studio agents

## Understanding MCP (Model Context Protocol)

This lab introduces MCP concepts and shows how to integrate them with Copilot Studio. MCP is a new open-source standard protocol that allows AI assistants to securely connect to external data sources and tools. 

MCP is like a “universal plug” that lets AI models connect to tools, apps, and data. Just like USB-C connects your phone to anything else. MCP helps AI agents do more (like calling APIs, reading files, sending messages, etc.) without needing custom code for each task.
With MCP, developers save time and make AI solutions more powerful, flexible, and easier to maintain.

In the following diagram you can see the high-level architecture of MCP.

![The general architecture of MCP (Model Context Protocol)](https://microsoft.github.io/copilot-camp/assets/images/MCP-Architecture.png)

The architecture defines the following objects:

- **MCP Host**: The AI application that coordinates and manages one or multiple MCP clients
- **MCP Client**: A component that maintains a connection to an MCP server and obtains context from an MCP server for the MCP host to use
- **MCP Server**: A program that provides context to MCP clients

Every MCP Server can expose:

- **Tools**: Functions that your LLM can actively call and decides when to use them based on user requests. Tools can write to databases, call external APIs, modify files, or trigger other logic.
- **Resources**: Passive data sources that provide read-only access to information for context, such as file contents, database schemas, or API documentation.
- **Prompts**: Pre-built instruction templates that tell the model to work with specific tools and resources.

The communication between an MCP Client and the corresponding MCP Server relies on two available protocols:

- **stdio (local)**: for MCP Servers running locally on your environment
- **Streamable HTTP (remote)**: for MCP Servers publicly available, like the you are going to create in this lab

Regardless what the transport protocol is, the communication relies on JSON-RPC 2.0 messages and can be accessed anonymously or can be secured with API Keys or OAuth 2.0.

You can learn more about MCP reading the content available in the [Model Context Protocol (MCP) for beginners](https://github.com/microsoft/mcp-for-beginners) training class.

## Exercise 1 : Setting up the MCP Server

In this exercise you are going to setup a pre-built MCP server that provides HR candidates management functionality. The server is based on Microsoft .NET and relies on the MCP SDK for C#. The server provides tools to manage a hypothetical list of job candidates. In this exercise you are going to build and configure the server, so that you can run it locally.

### Step 1: Understanding the MCP Server and prerequisites

The HR MCP server that you will be consuming in this lab provides the following tools:

- **list_candidates**: Provides the whole list of candidates
- **search_candidates**: Searches for candidates by name, email, skills, or current role
- **add_candidate**: Adds a new candidate to the list
- **update_candidate**: Updates an existing candidate by email
- **remove_candidate**: Removes a candidate by email

The server manages candidates information including:

- Personal details (firstname, lastname, full name, email)
- Professional information (spoken languages, skills, current role)

For the sake of simplicity, all the candidates are based on a pre-defined list loaded from a JSON file.

### Step 2: Building and running the MCP Server

Open Visual Studio Code and the open the folder `c:\labs\hr-mcp-server`.

![The outline of the HR MCP Server project in Visual Studio Code showing the server files and candidate data.](https://microsoft.github.io/copilot-camp/assets/images/make/copilot-studio-06/mcp-server-01.png)

Investigate the main elements and inspect the following files of the project:

- `Configuration`: folder with the `HRMCPServerConfiguration.cs` file defining the configuration settings for the MCP server.
- `Data`: folder with the `candidates.json` file providing the list of candidates.
- `Services`: folder with the `ICandidateService.cs` interface and the actual `CandidateService.cs` implementation of a service to load and manage the list of candidates.
- `Tools`: folder with the `HRTools.cs` file defining the MCP tools and the `Models.cs` file defining the data models used by the tools.
- `DevTunnel_Instructions.MD`: instructions about how to expose the MCP server via a dev tunnel.
- `Progam.cs`: the main entry point of the project, where the MCP server gets initialized.

Open a new terminal window from within Visual Studio Code or simply start a new terminal window and move to the root folder of the MCP server project that you just opened. Then install dependencies, build, and start the .NET project by invoking the following command:

```
dotnet run
```

Check that the MCP server is up and running. You should be able to consume the server via browser at the URL `http://localhost:47002/`. You will see an error inside a JSON message, that's ok. It means that you are reaching the MCP server.

### Step 3: Configure the dev tunnel

Now, you need to expose the MCP server with a public URL, so that your Microsoft Copilot Studio agent can consume it from the cloud. Since you are running the server locally on your development machine, you need to rely on a reverse proxy tool to expose your `localhost` via a public URL. For the sake of simplicity, you can use the dev tunnel tool provided by Microsoft, following these steps:

- Open a new terminal windows in Visual Studio Code
- Login with dev tunnel, executing the following command and using the Microsoft 365 work or school account:

**Username: +++@lab.CloudPortalCredential(User1).Username+++**

**Password: +++@lab.CloudPortalCredential(User1).Password+++**

```
devtunnel user login
```

- If prompted by the login dialog, select "No, this app only"
- Host your dev tunnel, executing the following commands:

```
devtunnel create hr-mcp-@lab.User.Id -a --host-header unchanged
```

```
devtunnel port create hr-mcp-@lab.User.Id -p 47002
```

```
devtunnel host hr-mcp-@lab.User.Id
```

The command line will display the connection information, such as:

![The dev tunnel running in a console window showing the hosting port, the connect via browser URL, and the URL to inspect network activity.](https://microsoft.github.io/copilot-camp/assets/images/make/copilot-studio-06/mcp-server-02.png)

Copy the "Connect via browser" URL and save it in a safe place.

Be sure to leave both the dev tunnel command and the MCP server running as you do the exercises in this lab. If you need to restart it, just repeat the last command `devtunnel host hr-mcp-@lab.User.Id`.

### Step 4: Testing the MCP server

You are now ready to test the MCP server on your local environment. For the sake of simplicity, you can use the [MCP Inspector](https://github.com/modelcontextprotocol/inspector). Start a terminal window and run the following command:

```
npx @modelcontextprotocol/inspector
```

The Node.js engine will download and run the MCP Inspector, in the terminal window you should see an output like the following one.

![The output of the MCP inspector when started in a terminal window. You have the proxy port that the MCP Inspector is listening on and the URL of the MCP Inspector.](https://microsoft.github.io/copilot-camp/assets/images/make/copilot-studio-06/mcp-inspector-01.png)

The browser will start automatically and you will see the following interface.

![The web interface of the MCP Inspector. On the left there are the settings to configure the MCP Server and the "Connect" button to connect to the actual MCP server.](https://microsoft.github.io/copilot-camp/assets/images/make/copilot-studio-06/mcp-inspector-02.png)

Configure the MCP Inspector with the following settings:

- 1️⃣ **Transport type**: Streamable HTTP
- 2️⃣ **URL**: the URL that you saved from the "Connect via browser" of the dev tunnel

Then select the 3️⃣ **Connect** button to start consuming the MCP server. The connection should be successful, and you should be able to have a green bullet and the message **Connected** just below the connection handling commands.

Now, in the Tools section of the screen, select the 1️⃣ **List Tools** command to retrieve the list of tools exposed by the MCP server.
Then, select the 2️⃣ **list_candidates** tool, and then select 3️⃣ **Run tool** to invoke the selected tool.

![The web interface of the MCP Inspector when listing the tools and invoking the "list_candidates" tool. There are commands to "List Tools", one item for each of the tools offered by the MCP server, and a command "Run tool" to invoke a single tool.](https://microsoft.github.io/copilot-camp/assets/images/make/copilot-studio-06/mcp-inspector-03.png)

In case of successful response, you will see a **Success** message in green and the output of the tool invocation.
In the **History** section you can always review all the invocations sent to the MCP server.

![The web interface of the MCP Inspector when invoking a tool. There is a green successful message and the actual output of the tool invocation.](https://microsoft.github.io/copilot-camp/assets/images/make/copilot-studio-06/mcp-inspector-04.png)

You are now ready to consume the MCP server from an agent in Microsoft Copilot Studio.

## Exercise 2 : Creating a New Agent in Copilot Studio

In this exercise you are going to create a new agent in Microsoft Copilot Studio that will consume the MCP server you configured in Exercise 1.

In order to use Microsoft Copilot Studio in your lab environment, you need to activate a product license following these steps:

- Open a browser and go to `https://copilotstudio.microsoft.com`. Login using the work or school account of your Microsoft 365 tenant:

**Username: +++@lab.CloudPortalCredential(User1).Username+++**

**Password: +++@lab.CloudPortalCredential(User1).Password+++**

- If this is the very first time you run Copilot Studio and if you don't have a license, you will see the following screen through which you will be able to start a trial period.

![The web page to start a trial period for Copilot Studio. You need to provide your country, to choose whether you want to receive messages from Microsoft about offerts, and to select to start the free trial period.](https://microsoft.github.io/copilot-camp/assets/images/make/copilot-studio-00/mcs-trial-01.png)

### Step 1: Creating the new agent

Once you activated the Copilot Studio license, select **Create** in the left navigation menu of Copilot Studio, then choose **Agent** to create a new agent, or simply start with the agent creation wizard that you will see for the first time.

Choose to **Configure** and define your new agent with the following settings:

- **Name**: 

```
HR Candidate Management
```

- **Description**: 

```
An AI assistant that helps manage HR candidates using MCP server integration 
for comprehensive candidate management
```

- **Instructions**: 

```
You are a helpful HR assistant that specializes in candidate management. You can help users search for candidates, check their availability, get detailed candidate information, and add new candidates to the system. 
Always provide clear and helpful information about candidates, including their skills, experience, contact details, and availability status.
```

![The agent creation dialog in Copilot Studio with the name, description, and instructions filled in for the "HR Candidate Management" agent.](https://microsoft.github.io/copilot-camp/assets/images/make/copilot-studio-06/create-agent-01.png)

Select **Create** to create your new agent.

### Step 2: Configuring the agent's conversation starters

After creating the agent, you'll be taken to the agent configuration page. Wait for the **Publish** command in the upper right corner to become enabled. Then, scroll down and in the **Suggested prompts** section, add these helpful prompts:

1. Title: `List all candidates` - Prompt: `List all the candidates`
1. Title: `Search candidates` - Prompt: `Search for candidates with name [NAME_TO_SEARCH]`
1. Title: `Add new candidate` - Prompt: `Add a candidate with firstname [FIRSTNAME], lastname [LASTNAME],  e-mail [EMAIL], role [ROLE], spoken languages [LANGUAGES], and skills [SKILLS]`

![The agent configuration page showing the "Suggested prompts" sections filled in with the suggested information.](https://microsoft.github.io/copilot-camp/assets/images/make/copilot-studio-06/configure-agent-01.png)

Select the **Save** button to confirm your changes.

## Exercise 3 : Integrating MCP Server with Copilot Studio

In this exercise you are going to configure the integration between your MCP server and the Copilot Studio agent.

### Step 1: Adding tools exposed by the MCP server

In your agent, navigate to the 1️⃣ **Tools** section and select 2️⃣ **+ Add a tool**.

![The "Tools" section of the agent with the "+ Add a tool" command highlighted.](https://microsoft.github.io/copilot-camp/assets/images/make/copilot-studio-06/mcp-integration-01.png)

Choose 1️⃣ **Model Context Protocol** group to see all the already existing MCP servers available to you agent. Now select 2️⃣ **+ New tool** to add the actual HR MCP server.

![The panel to add new tools, with the "+ New tool" command highlighted.](https://microsoft.github.io/copilot-camp/assets/images/make/copilot-studio-06/mcp-integration-02.png)

A new dialog shows up allowing you to select the kind of tool that you want to add. Select the **Model Context Protocol** option.

![The dialog to add a new tool with the "Model Context Protocol" option highlighted.](https://microsoft.github.io/copilot-camp/assets/images/make/copilot-studio-06/mcp-integration-03.png)

A new dialog will open, allowing you to configure the new MCP server providing name, description, URL, and authentication method.

Provide a name for the MCP server, for example:

`HR MCP Server @lab.User.Id`

Provide a description, for example:

`Allows managing a list of candidates for the HR department`

Configure the URL of the server, providing the URL that you copied from the dev tunnel with name `[Connect via browser of your dev tunnel]`.

Select **None** as the authentication method and then select **Create** to configure the actual tool.

![The dialog to add a new MCP server to the agent. There are settings to configure the server name, the server description, the server URL, and the authentication method. There is also a command to "Create" the MCP server.](https://microsoft.github.io/copilot-camp/assets/images/make/copilot-studio-06/mcp-integration-04.png)

Once the tool will get created, you will see a new dialog window requesting you to connect to the MCP server.

![The dialog to connect to the MCP server. There is a "Connection" status with "Not connected" value.](https://microsoft.github.io/copilot-camp/assets/images/make/copilot-studio-06/mcp-integration-05.png)

Select the `Not connected` option and then select **Create a new connection**. Follow the steps and you will be able to connect to the target MCP server.

![The option to "Create a new connection" to the MCP server.](https://microsoft.github.io/copilot-camp/assets/images/make/copilot-studio-06/mcp-integration-06.png)

Once the connection is completely configured, you can select the **Add and configure** command in the dialog window and see the MCP server and tools properly configured.

![The dialog to add the "HR MCP Server" connector as a tool to the current agent in Copilot Studio. There are buttons to "Add to agent" and to "Add and configure", as well as a button to "Cancel".](https://microsoft.github.io/copilot-camp/assets/images/make/copilot-studio-06/mcp-integration-09.png)

All the tools exposed by the MCP server are now available to your agent, as you can verify in the window displaying the MCP server details and tools.

![The details about the settings and tools of the MCP server that you just registered. There is the list of tools exposed by the server.](https://microsoft.github.io/copilot-camp/assets/images/make/copilot-studio-06/mcp-integration-10.png)

### Step 2: Test the new MCP server integration

Publish your agent by selecting **Publish** in the top right corner. Once published, test the agent in the integrated Test panel using the following prompt:

```
List all candidates
```

The agent should use the MCP server's `list_candidates` tool to return a complete list of all candidates in your HR system.
However, in order to being able to consume the list of candidates you might need to connect to the target connector. As such, if Copilot Studio will ask you to **Open connection manager**, connect to the MCP server, and then **Retry** the request.

![The initial dialog with the agent, which prompts the user to open the connection manager to connect to the MCP server and then to retry the request, once the connection is established.](https://microsoft.github.io/copilot-camp/assets/images/make/copilot-studio-06/mcp-test-01.png)

Once the connection is established, you can get the actual list of candidates from the HR MCP server.

![The list of candidates retrieved from the HR MCP Server.](https://microsoft.github.io/copilot-camp/assets/images/make/copilot-studio-06/mcp-test-02.png)

You can also make the agent available in the Microsoft 365 Copilot Chat. To do so, publish the agent by seleting the **Publish** command in the upper right corner and confirming that you want to publish it. 

Once the agent is published select the 1️⃣ **Channels** section, then select the 2️⃣ **Teams and Microsoft 365 Copilot** channel, check the 3️⃣ **Make agent available in Microsoft 365 Copilot** option, and then select the 4️⃣ **Add channel** command. Wait for the channel to be enabled, then close the channel side panel and publish the agent again selecting the **Publish** command of the agent in the top right corner.

![The interface to publish an agent in the "Teams and Microsoft 365 Copilot" channel. There is a checkbox to make the agent available in Microsoft 365 Copilot and a command to "Add channel".](https://microsoft.github.io/copilot-camp/assets/images/make/copilot-studio-06/agent-publish-m365-chat-01.png)

Now, open the **Teams and Microsoft 365 Copilot** channel again and select the command **See agent in Microsoft 365** to add the agent to Microsoft 365 Copilot.

![The interface to publish an agent in the "Teams and Microsoft 365 Copilot" channel with the "See agent in Microsoft 365" command highlighted.](https://microsoft.github.io/copilot-camp/assets/images/make/copilot-studio-06/agent-publish-m365-chat-02.png)

You will see the interface to add the agent to Microsoft 365 Copilot, select **Add** and then **Open**, in order to play with the agent in Microsoft 365 Copilot.

![The interface to add the agent to Microsoft 365 Copilot. There are information about the agent and a command to "Add" the agent to Microsoft 365 Copilot.](https://microsoft.github.io/copilot-camp/assets/images/make/copilot-studio-06/agent-publish-m365-chat-03.png)

You can now play with the agent in Microsoft 365 Copilot, notice the suggested prompts in the UI of the agent.
Now, for example, you can try with another prompt like:

```
Search for candidate Alice
```

![The Microsoft 365 Copilot chat interface with the suggested prompts configured for the "HR Candidate Management" and the prompt "Search for candidate Alice" ready to be processed.](https://microsoft.github.io/copilot-camp/assets/images/make/copilot-studio-06/mcp-test-copilot-01.png)

Now the agent should use the MCP server's `search_candidates` tool and return only one candidate matching the search criteria.
However, since we are in the Microsoft 365 Copilot context, you will need to connect again to the MCP server, using the Microsoft Copilot Studio connections management interface.

![The Microsoft 365 Copilot chat instructing the user to "Open the connection manager" to verify credentials and connect to the MCP server.](https://microsoft.github.io/copilot-camp/assets/images/make/copilot-studio-06/mcp-test-copilot-02.png)

Once connected, you will be able to run again the prompt and get the expected response.

![Microsoft 365 Copilot showing information about the candidate Alice Johnson, who is matching the search criteria defined in the prompt.](https://microsoft.github.io/copilot-camp/assets/images/make/copilot-studio-06/mcp-test-copilot-03.png)

### Step 3: Advanced interaction with the agent (bonus step)

This is a bonus step, depending on the leftover time you can skip it or you can go through it.

It is now time to test a much more advanced tool, like the `add_candidate` one to add a new candidate to the HR system. Use the following prompt:

```
Add a new candidate: John Smith, Software Engineer, skills: React, Node.js, email: john.smith@email.com, speaks English and Spanish
```

The agent will understand your intent, will extract the input arguments for the `add_candidate` tool, and will invoke it adding a new candidate to the list. The response from the MCP server will be a simple confirmation.

![The agent confirming that a new candidate has been added to the HR system via the MCP Server.](https://microsoft.github.io/copilot-camp/assets/images/make/copilot-studio-06/mcp-test-copilot-04.png)

You can double check the outcome by listing again the whole list of candidates. You can find `John Smith` as a new candidate at the end of the list.

![The updated list of candidates retrieved from the HR system via the MCP Server. The newly added candidate with name John Smith is at the end of the list.](https://microsoft.github.io/copilot-camp/assets/images/make/copilot-studio-06/mcp-test-copilot-05.png)

You can also have fun with other prompts like:

```
Update the candidate with email bob.brown@example.com to speak also French
```

or:

```
Add skill "Project Management" to candidate bob.brown@example.com
```

or:

```
Remove candidate bob.brown@example.com
```

The agent will invoke the right tools for you and will act accordingly to your prompts.

Well done! Your agent is fully functional and capable of consuming all the tools exposed by the HR MCP server.

