# Money Laundering Dataset Generator

## WHAT IS IT?

This model attempts to simulate a financial transactions dataset generation, with the presence of money laundering operations. In this model, the agents are people who have a bank account and eventually performs money laundering transactions. The model generates a file with the transactions (with and without ml) at the end of this execution. Concerning the Money Laundering transactions, this model tries to cover the following techniques generally performed by criminals:

- __Smurfing__: The repeated transaction sets have a standard deviation attached, which covers it's identification.

- __Passage Accounts__: Accounts used only to transfer the amount to another one, to prevent the finding of money source at the investigation.

- __Transaction Values Rounding__: The repeated transactions generally are rounded to a value divisible by 1,000.

## HOW IT WORKS

The model has two types of agents:

- __Person__: The agent who will open the accounts and take the decisions. It owns a predisposition value to realize money laundering (between 0 and 1) and the number of connections in the social network, used during its initialization.

- __Account__: The account used by a person to perform the financial transactions. The accounts are associated to a financial institute identifier. They have a variable to list the remaining scheduled transactions to perform and two boolean variables to indicate if it was the last opened by the owner and if it is the main owner's account or just a passage account.

People are arranged in a communication network, structured as an undirected graph. They select the destination of their transaction considering only their links in the network.


### SETUP

In the setup, a number of people (setable trough the variable `n-people`) is created in the environment, with a random predisposition value. Then, the social network is constructed, according to the following constraints:

- Each person will have a number of connections smaller than a global maximum number value (and this value is setable through the variable `max-connections`). 
- Each person will have at least one connection. To attend this constraint, a unique connection is created initially to each person before the creation of the other links to attenf the person's number of connections.
- People with similar predisposition are more likely connected. To attend this constraint, each other person will have a weight associated at the moment of the choice to be the one person connection, which is obtained from the difference between two person's predisposition minus 1, that is, smaller differences generates a bigger weight.

### EXECUTION

At each step of the execution, a proportion of people will schedule a transaction. To each person, it is asked to perform a transaction, which will be a money laundering operation or not according to a Bernoulli Distribution with the probability determined by the product of the person's predisposition and a criminal influence factor. Each of these situations have their own particularities:
- If the transaction is Money Laundering: 
	- The most likely destination are the ones with biggest predisposition (also chosen trough weights).
	- The amount has a biggest probability to be higher than the maximum permitted value. Various successive transactions are scheduled to cover the total.
	- A layer scheme with passage accounts can be constructed or not (with 50% probability) and they are randomly owned by the destination person or the sender.
	- The financial institution of the passage accounts is most likely different of the origin account's one.
	- Each scheduled transaction's amount value has it's average next to a value divisible by 1,000 with a small random deviation (positive or negative), or a little smaller than the maximum permitted with a small negative deviation.
- If the transaction is not a Money Laundering:
	- The amount will be lesser than the maximum permitted value.
	- The transaction will be done within a single timestep.

After scheduling, at the same timestep, each account is verified in order to perform their scheduled transactions to that timestep. The transactions are recorded in an output file (`output.csv`) which has the register of each transaction described by the following variables:

- __`TIMESTAMP`__: The transaction timestamp.
- __`ID_ORIGIN`__: The `who` variable of the origin.
- __`ID_DESTINATION`__: The `who` variable of the destination. 
- __`ACC_ORIGIN`__: The `who` variable of the origin's account.
- __`ACC_DESTINATION`__: The `who` variable of the destination's account.
- __`FI_ORIGIN`__: The financial institution number of the origin.
- __`FI_DESTINATION`__: The financial institution number of the destination.
- __`VALUE`__: The transaction value.
- __`IS_ML`__: If is a money laundering (1) or not (0).



## HOW TO USE IT

You can initialize the model by "setup" button and execute it by the "go" button. There are many sliders to control other variables in the model:

- `n-people`: Determines the number of people created in the setup.
- `criminal-inf`: Determines the factor of criminal influence in the model. Higher values will result in most Money Laundering transactions.
- `n-financial-inst`: The number of financial institutions in the model.
- `max-connections`: The maximum number of connections to each person in the social network.
- `em-per-timestamp`: The proportion of the people who will perform emissions at each timestamp.
- `max-perm-value`: The maximum permitted transaction value.

It is possible to see the proportion of Money Launderig and passage accounts transactions at each timestamp through a line graph, as the numeric number of total transactions and money laundering transactions. In the environment world window, it is possible to see the people's social network, and the transactions being performed between them at each timestep. When the link becomes green, there is a normal transaction between the two persons linked. When the link becomes red, it's a Money Laundering transaction.

At each time when the model setups, a new "output.csv" file is created containing only the reader with the column names. During the execution, the transactions performed are registered in the last line of this file, building the dataset. 


## NETLOGO FEATURES

This model makes use of the `rnd` extention to generate some random variables.


## CREDITS AND REFERENCES

This model was inspired by the following works:

- https://ccl.northwestern.edu/2005/Generating_Fraud_Agent_Based_Financial_N.pdf
- https://github.com/EdgarLopezPhD/PaySim
