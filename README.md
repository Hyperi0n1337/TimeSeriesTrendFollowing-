# Time Series Trend Following 

•	Algorithmic trading strategy using moving averages crossover to capture momentum factor (potential source of alpha)

•	Mitigated idiosyncratic risk by diversifying time periods in line with profitable managed futures strategies

•	Leveraged trend strength, MA crossovers, and candle patterns for entry/exit, adjusting positions during consolidations

•	A powerful portfolio diversification tool with near-zero correlation to the stock market and positive expected return


# Summary

This MQL4 code is for a trading strategy in MetaTrader that utilizes a moving average crossover to execute trades and includes criteria to exit the trades. 

In plain English:

Moving Averages Setup:

The strategy uses two sets of moving averages (MAs): small fish and big fish.
For small fish, there are six MAs with different periods (3, 5, 8, 10, 12, 15).
For big fish, there are six MAs with different periods (30, 35, 40, 45, 50, 60).
Configuration Parameters:

Various input parameters allow the user to configure the strategy, such as period lengths, trend windows, consolidation settings, and thresholds.
Initialization:

The OnInit function initializes the strategy by setting up the small and big fish MAs, configuring parameters, and initializing various variables and objects.
OnTick Function:

The main trading logic is implemented in the OnTick function, which is called on each new tick.
The strategy checks if it's the first iteration and initializes some variables and objects accordingly.
It updates the peaks of the entered trend based on the bid price.
If it's a new time frame (candle), it updates support and resistance levels and checks if the big fish is currently in an uptrend or downtrend.
If a new trend is detected, it looks for specific candle patterns (big shadow, kangaroo tail, engulfing) to trigger trade entries.
It also checks for consolidation and adjusts positions accordingly.
OnTrade Function:

The OnTrade function is called when there are changes in the trading account (opening or closing positions).
It resets variables related to the entered trend when all positions are closed.
IsFishEntry Function:

This function determines whether the current conditions are suitable for entering a trade.
It checks various conditions, including the trend strength, small fish crossover, small fish stab, and price action stab.
DrawArrow Function:

It draws arrows on the chart based on certain conditions and candle patterns.
OpenPosition Function:

Opens a new position when specific criteria are met, setting stop-loss and take-profit levels.
AdjustPosition Function:

Adjusts existing positions based on the current trend and market conditions.
Comments and TODOs:

There are comments throughout the code explaining different sections and providing insights into potential improvements or considerations for the strategy.