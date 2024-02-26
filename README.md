# doji_reversal_mql5
This Expert Advisor attempt to create a Simple Backtester on Metatrader 5 with a doji candle reversal strategy, allowing for automated backtesting and optimisation of FOREX strategies.

This is a discretionary startegy that relies on the doji CandleStick Pattern, RSI and EMA as confluence. The stategy attempt to look for reversals in a longer term trend. The doji candle acts as a trigger to indicate the possiblity of a reversal, the RSI acts as an overbought / oversold filter, while a 200 EMA line signals the overall trend.

//----Long Entry----//
doji CandleStick Pattern Formed
RSI shows an oversold condition (value < 30)
EMA line acts as confirmation indicator where candle must close above EMA line
If there is a long entry, first check if there are any trades open, if there is a short trade, close short trade and enter new trade. If there is a long trade, this long entry is considered invalid
Exit when take profit / stop loss is hit, or the RSI turns overbought

//----Short Entry----//
doji CandleStick Pattern Formed
RSI shows an overbought condition (value > 70)
EMA line acts as confirmation indicator where candle must close below EMA line
If there is a short entry, first check if there are any trades open, if there is a long trade, close long trade and enter new trade. If there is a short trade, this long entry is considered invalid
Exit when take profit / stop loss is hit, or the RSI turns oversold

//----Trade Management----//
2 Trades are entered when entry condition are met. User can choose between Static or Trailing Stop Loss
In the static option, a fixed risk to reward was of 2:1 will be used
In the trailing option, 1 Trade will be will be entered with a 2:1 risk to reward ratio, while the other trade has no trade profit. When the take profit of the first trade is Hit, the Stop Loss of the second trade will be moved to break even price and a 1x ATR trailing Stop loss will be implemented

//----Risk Management----// 
ATR based stop loss is used, where the stop loss is 1x ATR below entry price for long trades and 1x ATR above entry price for short trade. A 1:2 risk to reward ratio is used. By default a 2% risk per trade is used

//----Features----//
Risk per trade tool: Set max loss per trade in base currency, adapted to work for JPY forex pairs
Compounding vs Fixed lot size
Variable Stop Loss / Take Profit multiplier
Parameters of RSI / EMA can be modified
doji CandleStick parameters can be changed to determine the validity of the pattern
Trade is entered at the start of a new candle

//----Notes----//
Trade is entered when a the previous candle closes and the new candle opens. Depending on your broker, the trading window is different from the candle opening time. This may cause an invalid trade entry when market is closed. A timer is added in the EA which can be adjust based on the difference in timing of candle open and trading Open.
Trade can be entered immediately after a trade is exited
doji candle is defined as a candle where the upper and lower wicks are greater than 1.2x ATR, while the distance between close and open price is within 20% of the distance between wicks. 
