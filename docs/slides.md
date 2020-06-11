name: Nomad MultiCloud Demo
class: title, shelf, no-footer, fullbleed
background-image: url(https://hashicorp.github.io/field-workshops-assets/assets/bkgs/HashiCorp-Title-bkg.jpeg)
count: false

# HashiCorp Nomad MultiCloud
## Demo Infrastructure

![:scale 15%](https://hashicorp.github.io/field-workshops-assets/assets/logos/logo_nomad.png)

???
This slide deck briefly covers the work for this repository.  The ultimate goal is to demonstrate the flexibility of Nomad as an Orchestrator across multiple environments

---
layout: true

.footer[
- Copyright © 2019 HashiCorp
- ![:scale 100%](https://hashicorp.github.io/field-workshops-assets/assets/logos/HashiCorp_Icon_Black.svg)
]

---
exclude: true

name: slides-link
# The Slide Show
## You can follow along on your own computer at this link:
### tbd

???
Here is a link to the slides so you can follow along, but please don't look ahead!

Hidden:  Custom diagrams can be found at Lucidchart
https://app.lucidchart.com/invitations/accept/f8f731cd-104c-4aa5-89f5-abd381671173

---
exclude: true

class: img-right
name:  Impetus for the Project
# What to Do?

![ServerElection](images/dumpsterfire.png)

.smaller[
* Isolation and Lockdown
    * Keep Ourselves Busy
    * Keep Our Kids Busy!
* Virtual Group Activities
    * Watch Parties
    * Online Games
]

???
Yup, the dumpster fire we call 2020 increased in fervency, and as we all went on lockdown, what would we do with all of that time?  What would our kids do with all of that time?  I know what I would have done...and it wasn't anything good.  So what could we do?  We know everything went online...we could do watch parties, and online games!  Hey, games, that would be a great thing for my Scouts to do together (yes, believe it or not, I'm a Scout leader).  So, I set out on a journey

---
name:  The Seed of Minecraft
# Collaborative Games Online
.smaller[
* Requirements:
    * Online Collaboration
    * Appropriate for Youth
* Minecraft!
* Minecraft with Nomad!
    * Java App - Java Task Driver
    * Container Storage (CSI) - Shared World
    * Simple and Easy

]

???
What games can they do online, work together, AND that would be "Scout" appropriate.  Well...Minecraft!  They can build something together.  And then it hit me...with Nomad Container Storage released, along with auto-scaling, wouldn't it be cool to put a simple Minecraft system together using Nomad?  I can use the Nomad Java Driver, and CSI, and play games as part of my work!  It will be simple!  Well, dreams aren't always reality...

---
class: img-right
name:  Squirrel!
# Start Out Easy...

.smaller[
* Simple Nomad System
* Java and CSI Jobs
* Single Cloud, Single Environment
]

???
My intention was to build a simple Nomad system and hack together a demo, and possibly a blog post.

---
class: img-right
name:  Squirrel!
# Start Out Easy, and Then...

![ServerElection](images/squirrel.png)

.smaller[
* Simple Nomad System
* Java and CSI Jobs
* Single Cloud, Single Environment
]

???
And then I found Doug.  Yup, I found it to be so easy to squirrel out and start going down the "what if I did this" route.  Note, this is a great example of why every POC/POV/demo needs to be well defined and bounded!

---
name:  End Result
# Current System Architecture

![ServerElection](images/layout.png)

???
This is what I ended up with, at least for now.  I have a Server Cluster with Nomad and Consul servers running.  I have 4 Linux nodes in AWS, 1 Windows node in Azure, all connected to that cluster.  And of course, I had to add DataDog into the mix for logging and metrics.

---
name:  Creation Flow
# Two Creation Processes (Step 1)

.smaller[
* Terraform File Kicks Off Flow
    * Builds Necessary Azure Resources for Image
    * Azure Packer Image (using JSON)
    * AWS Packer Image (using HCL)
* Manifest files produced as artifacts
    * Image Information feeds System Creation
]
.center[![:scale 80%](images/ImageCreationFlow.png)]

???
Within the 'Image Creation' directory, we have a Terraform file which builds some resources in Azure that are necessary to house the image, and then Terraform uses local-exec to build both Azure and AWS Images.  For variety, I used JSON for the Azure build, and HCL for the AWS build.  This not only provides examples but also shows how much simpler HCL is.  Images include Consul, Nomad, DataDog, and some other goodies.  Manifest files are produced as output to feed the system creation.

---
class: img-right
name:  Creation Flow Part 2
# Two Creation Processes (Step 2)

![ServerElection](images/SystemCreationFlow.png)

.smaller[
* A Single Terraform File to Build Them All!
    * Manifest Files and Variables Feed
    * AWS and Azure resources built in Parallel
    * Applications Provisioned as part of the process
]

???
-  Now with the images built, we can build the system.  Terraform creates all of the resources for both AWS and Azure, and provisions using remote-exec, powershell, and a template file.  The idea was to try multiple methods for comparisons and examples moving forward.

---
name:  Multi-region Federation
# Operating Across Regions

.smaller[
* Multiple Nomad Regions can be Federated Together
* Jobs are submitted within region, and can be submitted across regions
* ACL Tokens, Policies, and Sentinel Policies are shared across regions - Application/State Data NOT Shared
]

.center[![:scale 80%](images/Multi-Region.png)]

???
- Clusters can federate across regions using WAN Gossip
- Only ACL, Policies, and Sentinel Policies are shared across regions (no application data).

---
name:  Multi-region Federation
# Region Server Failure

.smaller[
* If all servers in a region fail, clients can access servers in a federated region
* Servers must be discoverable
* Requires RPC and Raft across Regions
]

.center[![:scale 80%](images/Failed-Region.png)]

???
-  If the server cluster in one region goes down completely, the server cluster in another region can facilitate management.
-  This multi-region federation requires RPC and Serf support across regions.

---
class: img-right
Name:  Nomad Layout and Comms
# Nomad Communications
![NomadArchitectureRegion](https://www.nomadproject.io/assets/images/nomad-architecture-region-a5b20915.png)

.smaller[
* 3-5 Server Nodes
* The Leader Replicates to Followers
* Followers forward Client Data and Requests to Leader
* Servers send Allocations to clients
* Clients Communicate with all Servers over RPC
]

???
-  Within the Server Cluster, we have a Leader, and we have Followers.
-  Leaders are elected via quorum (which is why it is important to have 3-5 nodes) using Consensus, based on RAFT.
-  Leader of the servers makes all allocation decisions, and distributes to Followers.
-  Server push allocation and task assignments via RPC to each Server.

---
name: Nomad Scheduler Section
class: title, shelf, no-footer, fullbleed
background-image: url(https://hashicorp.github.io/field-workshops-assets/assets/bkgs/HashiCorp-Title-bkg.jpeg)
count: false

# Nomad Scheduler Processes
## Evaluations, Allocations, Priorities, and Preemption

![:scale 15%](https://hashicorp.github.io/field-workshops-assets/assets/logos/logo_nomad.png)

???
Focusing more on the Scheduler process

---
class: img-right
Name:  Nomad Evaluation
# Nomad Scheduler Initiation - Evaluations

![NomadEvalAlloc](images/Nomad_eval_alloc.png)

An Evaluation is "Kicked Off" whenever ANY of the following occur
.smaller[
* New Job Created
* Job Updated or Modified
* Job or Node Failure
]

???
-  Evaluations to determine if any work is necessary.
-  Evaluation is initiated by a new job definition, an updated job definition, or some change to the infrastructure.
-  If necessary, a new Allocation maps tasks or task groups within jobs, to the available nodes

---
class: img-right

Name:  Nomad Scheduler
# Nomad Scheduler Initiation

![NomadEvaluationKickoff](images/Nomad_Evaluation_Kickoff.png)

.smaller[
* Regardless of how the Evalution is initiated, the evaluation can be sent to any of the server nodes.
* All Evaluations are forwarded to the Evaluation Broker on the Leader
* Evaluation remains in 'pending' state until the Leader queues the process
]

???
-  A new job, a modified or updated job, or any change in the system (job or node failure) will cause an evaluation to kick off.
-  Any of the server nodes can receive the evaluation request.
-  Evaluations are forwarded to a dedicated process on the Leader, called the evaluation broker.
-  Evaluation remains in 'pending' state until broker decides upon allocation

---
class: img-right

name:  Nomad Evaluation
# Nomad Evaluation
![EvaluationQueue](images/Evaluation_Queue.png)

Once the Evaluation Broker recieves the Evaluations, the Broker queues the changes in order based on priority.

Scheduler on Follower Nodes pick the Evaluations off the queue and start planning!

???
-  Here the evaluation Broker, residing on the leader node, manages the queue of pending evaluations.
-  Priority is determined based on Job definition
-  Broker ensures that somebody picks up the evaluation for processing.
-  Once the evaluation is picked up by a Scheduler, the planning begins!

---
Name:  Scheduling Workers
# Scheduler Operations

All Servers run Scheduling Workers
* One Scheduler per CPU core by default
* Four Default Schedulers Available
    * **Service** Scheduler optimized for long-lived services
    * **Batch** Scheduler for fast placement of batch jobs
    * **System** Scheduler for jobs to run on every node

???
-  Each server node runs one scheduler per CPU core.
-  Server chooses the proper scheduler, either for standard services, batch jobs, or system level jobs.

---
Name:  Scheduler Function Part 2
# Scheduler Processing
Now that the Scheduler has the job, let's look at what the it does...
.smaller[
1.  Identify available resources/nodes to run the job
2.  Rank nodes based on bin packing and existing tasks/jobs
3.  Select highest ranking node, and create allocation plan
4.  Submit allocation plan to leader
]
???
-  Server process has several steps
-  First it identifies the potential nodes, or available resources, that could accept the job.
-  Next take a look at the ideal nodes, based on bin packing and existing tasks.
   -  Bin packing ensures the most efficient usage of the resources.
-  Taking existing tasks into account minimizes co-locating tasks on the same servers.
-  Highest ranking node is chosen, the allocation plan is created, and submitted back to the Leader.

---
class: img-right
Name:  Plan Queue Processing
# Plan Queue Processing
![QueueProcessing](images/Queue_Processing.png)

Back to the leader now...
.smaller[
5.  Evaluate all submitted allocation plans
6.  Accept, reject, or partially reject the plan
7.  Return response to Scheduler for implementation, rescheduling, or termination
8.  Scheduler updates status of evaluation and confirms with Evaluation Broker
9.  Clients pick up allocation changes and act!
]

???
-  Leader makes final determination for allocation.
-  All pending plans are prioritized and eliminate any concurrency if it exists.
-  Leader will either accept or reject (or partial reject) the plan.
-  Scheduler can chose to reschedule or terminate the request
-  Scheduler updates the Evaluation Broker with the decision, and clients pick up any changes deemed necessary

---
Name:  End to End Flow
#  Flow Recap
![:scale 90%](images/Nomad_Overall_Flow.png)

---
Name:  Job Priority
# Job Priority
* Every Scheduler, Planner, Program Manager, deals with struggling priorities.
* **Nomad** is no different - Priority is processed during evaluation and planning
.smaller[
* Every job has an associated Priority
* Priority ranges from 1-100
* Higher number = higher priority
]

.center[What if higher priority jobs are scheduled?]


???
-  Nomad supports priority configuration with every Job, from 1 to 100.
-  The higher the number, the higher the priority.
-  What if a higher priority job is scheduled and resources are limited?

---
Name:  Preemption
# Preemption
.center[Preemption allows Nomad to adjust resource allocations based on Job priority.]
.smaller[
| Without Preemption            | With Preemption                  |
|-------------------------------|-------------------------------------------------|
|Jobs and tasks are allocated first come - first served |Evaluations performed regardless of resource availability |
|Pending Evaluations not allocated until resources available                   |Lowest priority jobs evicted if necessary|
|             |Output of 'Plan' identifies any preemptive actions|
]

???
-  Jobs are evaluated and allocated as they are delivered to the evaluation broker.
-  If resources aren't avialable, any evaluations will be stuck in pending state until resources become available.
-  With preemption, Nomad evicts lowest priority jobs if necessary.
-  Any preemption actions necessary are highlighted as an output of the 'Plan' operation

---
name: Nomad within HashiCorp
class: title, shelf, no-footer, fullbleed
background-image: url(https://hashicorp.github.io/field-workshops-assets/assets/bkgs/HashiCorp-Title-bkg.jpeg)
count: false

# Nomad Integrations
## The HashiCorp Ecosystem

![:scale 15%](https://hashicorp.github.io/field-workshops-assets/assets/logos/logo_nomad.png)

???
Nomad integrates well with other HashiCorp products.  We're just going to touch on teh functionality here.

---
name:  Nomad and Consul
# Nomad's Native Integration with Consul

.smaller[
* Automatic Clustering for Servers and Clients
* Service Discovery for Tasks and Jobs
* Dynamic Configuration for applications
* Secure communication between jobs and task groups using Consul Connect
]

???
-  Nomad Servers and Clients can automatically find each other within the network, minimizing configuration and being more address-flexible.
-  Consul enables application service nodes to be automatically discoverable within the cluster
-  Configuration files can be dynamically created utilizing environment variables or even Vault secrets with templating
-  Consul Connect can secure communication between services deployed in public or private clouds.

---
name:  Nomad and Vault
# Nomad's Native Integration with Vault

* Create and Distribute Vault tokens to be used by Tasks
* Nomad tasks retrieve Secrets from Vault
* Tasks access external services through short-lived credentials provided by Vault
* Tasks can also retrieve Nomad API tokens using Vault's  [Nomad Secrets Engine](https://www.vaultproject.io/docs/secrets/nomad/index.html)

???
-  Nomad's integration with Vault allows Vault tokens to be used by Nomad Tasks
-  Nomad's tasks can retrieve secrets directly from Vault
-  Vault can also provide short-lived credentials to Nomad tasks
-  Vault offers a native Nomad Secrets Engine