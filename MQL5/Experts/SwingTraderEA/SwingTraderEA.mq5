//+------------------------------------------------------------------+
//|                                               SwingTraderEA.mq5|
//|                        Copyright 2023, Your Name/Company|
//|                                             https://www.yourwebsite.com|
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Your Name/Company"
#property link      "https://www.yourwebsite.com"
#property version   "1.30" // Enhanced with volatility, R/R filters and opposite signal exit

//--- Input Parameters
//--- These parameters can be adjusted from the MetaTrader 5 terminal to optimize the EA's performance.
// Risk Management
input double RiskPercent = 1.0; // Risk per trade as a percentage of account balance.
input double StopLossATRMultiplier = 2.0; // Multiplier for ATR to set the Stop Loss distance.
input double TakeProfitATRMultiplier = 3.0; // Multiplier for ATR to set the Take Profit distance.

// Trade Filters & Exits
input double MinATRVolatilityPips = 10.0; // Minimum ATR value in pips to consider trading.
input double MinRiskRewardRatio = 1.5;   // Minimum Risk/Reward ratio (e.g., 1.5 means TP is at least 1.5x SL).
input bool   ExitOnOppositeSignal = true;  // Close open trades if an opposite signal appears.

// Indicator Settings
input ENUM_TIMEFRAMES HigherTimeframe = PERIOD_H4; // Higher Timeframe used to determine the main trend direction.
input int FastMAPeriod = 50; // Period for the Fast Moving Average on the current chart timeframe.
input int SlowMAPeriod = 200; // Period for the Slow Moving Average on both timeframes.
input int RSIPeriod = 14; // Period for the Relative Strength Index (RSI).
input int MACDFastEMAPeriod = 12; // Fast EMA period for MACD.
input int MACDSlowEMAPeriod = 26; // Slow EMA period for MACD.
input int MACDSignalSMAPeriod = 9; // Signal line period for MACD.
input int ATRPeriod = 14; // Period for the Average True Range (ATR), used for volatility calculation.

// Trailing Stop
input bool UseTrailingStop = true; // Enable or disable the trailing stop functionality.
input int TrailingStopPoints = 50; // Distance in points to trail the price.

// Include necessary libraries
#include <Trade/Trade.mqh>
#include <Trade/AccountInfo.mqh>

//--- Global objects
CTrade trade; // Trade object for executing orders
CAccountInfo account; // AccountInfo object for accessing account properties

//--- Indicator Handles
//--- These variables will store unique identifiers for each indicator instance.
int FastMA_Handle;
int SlowMA_Handle;
int RSI_Handle;
int MACD_Handle;
int ATR_Handle;
int TrendMA_Handle; // Handle for the higher timeframe MA

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//| This function is called once when the EA is attached to a chart. |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Initialize indicator handles for the current timeframe
   FastMA_Handle = iMA(_Symbol, _Period, FastMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
   if(FastMA_Handle == INVALID_HANDLE)
     {
      printf("Error creating Fast MA indicator");
      return(INIT_FAILED);
     }

   SlowMA_Handle = iMA(_Symbol, _Period, SlowMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
   if(SlowMA_Handle == INVALID_HANDLE)
     {
      printf("Error creating Slow MA indicator");
      return(INIT_FAILED);
     }

   RSI_Handle = iRSI(_Symbol, _Period, RSIPeriod, PRICE_CLOSE);
   if(RSI_Handle == INVALID_HANDLE)
     {
      printf("Error creating RSI indicator");
      return(INIT_FAILED);
     }

   MACD_Handle = iMACD(_Symbol, _Period, MACDFastEMAPeriod, MACDSlowEMAPeriod, MACDSignalSMAPeriod, PRICE_CLOSE);
   if(MACD_Handle == INVALID_HANDLE)
     {
      printf("Error creating MACD indicator");
      return(INIT_FAILED);
     }

   ATR_Handle = iATR(_Symbol, _Period, ATRPeriod);
   if(ATR_Handle == INVALID_HANDLE)
     {
      printf("Error creating ATR indicator");
      return(INIT_FAILED);
     }

   //--- Initialize indicator handle for the higher timeframe trend
   TrendMA_Handle = iMA(_Symbol, HigherTimeframe, SlowMAPeriod, 0, MODE_SMA, PRICE_CLOSE);
   if(TrendMA_Handle == INVALID_HANDLE)
     {
      printf("Error creating Higher Timeframe MA indicator");
      return(INIT_FAILED);
     }

   //--- Prepare the log file. A new file is created for each symbol.
   string fileName = "TradeLog_" + _Symbol + ".csv";
   int fileHandle = FileOpen(fileName, FILE_WRITE|FILE_CSV, ",");
   if(fileHandle != INVALID_HANDLE)
     {
      //--- Write header if the file is new/empty to structure the log.
      if(FileSize(fileHandle) == 0)
        {
         FileWriteString(fileHandle, "Timestamp,Symbol,OrderType,Price,LotSize,StopLoss,TakeProfit,Reason\n");
        }
      FileClose(fileHandle);
     }

   //--- Initialization successful
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//| Called when the EA is removed from the chart.                    |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Release indicator handles to free up memory.
   IndicatorRelease(FastMA_Handle);
   IndicatorRelease(SlowMA_Handle);
   IndicatorRelease(RSI_Handle);
   IndicatorRelease(MACD_Handle);
   IndicatorRelease(ATR_Handle);
   IndicatorRelease(TrendMA_Handle);
}

//+------------------------------------------------------------------+
//| Calculate Lot Size based on Risk                                 |
//| This function dynamically calculates the lot size for a new      |
//| trade based on the specified risk percentage and stop loss size. |
//+------------------------------------------------------------------+
double CalculateLotSize(double stopLossPoints)
{
   //--- Get account balance and calculate the amount to risk.
   double balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double riskAmount = balance * (RiskPercent / 100.0);

   //--- Get symbol properties required for calculation.
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double lotSizeStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);

   if(stopLossPoints <= 0 || tickValue <= 0)
     {
      return(minLot); // Return minimum lot size if SL or tick value is invalid.
     }

   //--- Calculate the monetary loss for one lot with the given stop loss.
   double lossPerLot = stopLossPoints * tickValue / tickSize;

   //--- Calculate the ideal lot size based on the risk amount.
   double lotSize = 0;
   if(lossPerLot > 0)
     {
      lotSize = riskAmount / lossPerLot;
     }
   else
     {
      return(minLot); // Return minimum lot size if loss per lot is invalid.
     }

   //--- Normalize lot size to comply with broker's volume step.
   lotSize = floor(lotSize / lotSizeStep) * lotSizeStep;

   //--- Clamp the lot size within the broker's allowed min/max limits.
   if(lotSize < minLot)
     {
      lotSize = minLot;
     }
   if(lotSize > maxLot)
     {
      lotSize = maxLot;
     }

   return(lotSize);
}

//+------------------------------------------------------------------+
//| Check for Buy Condition                                          |
//| This function checks if all conditions for a BUY trade are met.  |
//+------------------------------------------------------------------+
bool CheckBuyCondition()
{
   //--- Get indicator values for the last 2 completed bars.
   //--- We use index 0 for the most recently closed bar, and 1 for the one before it.
   double fastMA[], slowMA[], rsi[], macdMain[], macdSignal[], trendMA[], atrValue[];

   if(CopyBuffer(FastMA_Handle, 0, 1, 2, fastMA) < 2 ||
      CopyBuffer(SlowMA_Handle, 0, 1, 2, slowMA) < 2 ||
      CopyBuffer(RSI_Handle, 0, 1, 2, rsi) < 2 ||
      CopyBuffer(MACD_Handle, 0, 1, 2, macdMain) < 2 ||
      CopyBuffer(MACD_Handle, 1, 1, 2, macdSignal) < 2 ||
      CopyBuffer(TrendMA_Handle, 0, 1, 1, trendMA) < 1 ||
      CopyBuffer(ATR_Handle, 0, 1, 1, atrValue) < 1)
     {
      printf("Error copying indicator buffers for buy condition");
      return(false);
     }

   //--- Get the close price of the last completed bar.
   double lastClose = iClose(_Symbol, _Period, 1);

   //--- 1. Volatility Condition: Market must have enough movement.
   bool isVolatileEnough = (atrValue[0] > (MinATRVolatilityPips * _Point));

   //--- 2. Trend Condition (Higher Timeframe): Price must be above the slow MA on the higher timeframe.
   bool isHigherTFUptrend = (lastClose > trendMA[0]);

   //--- 3. Entry Conditions (Current Timeframe).
   bool isLocalUptrend = (fastMA[0] > slowMA[0]);
   // Bullish Crossover: MACD main line was below the signal line and is now above.
   bool isMomentumBuy = (macdMain[1] < macdSignal[1]) && (macdMain[0] > macdSignal[0]);

   //--- 4. Strength Condition: RSI should be above 50, indicating bullish territory.
   bool isStrengthBuy = (rsi[0] > 50);

   //--- All conditions must be true to open a buy trade.
   return(isVolatileEnough && isHigherTFUptrend && isLocalUptrend && isMomentumBuy && isStrengthBuy);
}

//+------------------------------------------------------------------+
//| Check for Sell Condition                                         |
//| This function checks if all conditions for a SELL trade are met. |
//+------------------------------------------------------------------+
bool CheckSellCondition()
{
   //--- Get indicator values for the last 2 completed bars.
   double fastMA[], slowMA[], rsi[], macdMain[], macdSignal[], trendMA[], atrValue[];

   if(CopyBuffer(FastMA_Handle, 0, 1, 2, fastMA) < 2 ||
      CopyBuffer(SlowMA_Handle, 0, 1, 2, slowMA) < 2 ||
      CopyBuffer(RSI_Handle, 0, 1, 2, rsi) < 2 ||
      CopyBuffer(MACD_Handle, 0, 1, 2, macdMain) < 2 ||
      CopyBuffer(MACD_Handle, 1, 1, 2, macdSignal) < 2 ||
      CopyBuffer(TrendMA_Handle, 0, 1, 1, trendMA) < 1 ||
      CopyBuffer(ATR_Handle, 0, 1, 1, atrValue) < 1)
     {
      printf("Error copying indicator buffers for sell condition");
      return(false);
     }

   //--- Get the close price of the last completed bar.
   double lastClose = iClose(_Symbol, _Period, 1);

   //--- 1. Volatility Condition: Market must have enough movement.
   bool isVolatileEnough = (atrValue[0] > (MinATRVolatilityPips * _Point));

   //--- 2. Trend Condition (Higher Timeframe): Price must be below the slow MA.
   bool isHigherTFDowntrend = (lastClose < trendMA[0]);

   //--- 3. Entry Conditions (Current Timeframe).
   bool isLocalDowntrend = (fastMA[0] < slowMA[0]);
   // Bearish Crossover: MACD main line was above the signal line and is now below.
   bool isMomentumSell = (macdMain[1] > macdSignal[1]) && (macdMain[0] < macdSignal[0]);

   //--- 4. Strength Condition: RSI should be below 50, indicating bearish territory.
   bool isStrengthSell = (rsi[0] < 50);

   //--- All conditions must be true to open a sell trade.
   return(isVolatileEnough && isHigherTFDowntrend && isLocalDowntrend && isMomentumSell && isStrengthSell);
}

//+------------------------------------------------------------------+
//| Log Trade Details to a CSV file                                  |
//| Records the details of each executed trade for later analysis.   |
//+------------------------------------------------------------------+
void LogTradeDetails(string orderType, double price, double lotSize, double sl, double tp, string reason)
{
   string fileName = "TradeLog_" + _Symbol + ".csv";
   int fileHandle = FileOpen(fileName, FILE_READ|FILE_WRITE|FILE_CSV, ",");

   if(fileHandle != INVALID_HANDLE)
     {
      //--- Move to the end of the file to append new data.
      FileSeek(fileHandle, 0, SEEK_END);

      //--- Write the trade details in CSV format.
      FileWriteString(fileHandle, TimeToString(TimeCurrent(), TIME_DATE|TIME_SECONDS) + ",");
      FileWriteString(fileHandle, _Symbol + ",");
      FileWriteString(fileHandle, orderType + ",");
      FileWriteString(fileHandle, DoubleToString(price, _Digits) + ",");
      FileWriteString(fileHandle, DoubleToString(lotSize, 2) + ",");
      FileWriteString(fileHandle, DoubleToString(sl, _Digits) + ",");
      FileWriteString(fileHandle, DoubleToString(tp, _Digits) + ",");
      FileWriteString(fileHandle, reason + "\n");

      FileClose(fileHandle);
     }
}

//+------------------------------------------------------------------+
//| Manage Trailing Stop                                             |
//| Adjusts the Stop Loss of open positions to lock in profits.      |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   if(!UseTrailingStop)
     {
      return; // Exit if trailing stop is disabled.
     }

   //--- Iterate through all open positions.
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      ulong positionTicket = PositionGetTicket(i);
      //--- Process only positions for the current symbol.
      if(positionTicket > 0 && PositionGetString(POSITION_SYMBOL) == _Symbol)
        {
         double currentPrice = 0;
         double newStopLoss = 0;
         double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
         double currentStopLoss = PositionGetDouble(POSITION_SL);
         long positionType = PositionGetInteger(POSITION_TYPE);

         if(positionType == POSITION_TYPE_BUY)
           {
            currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            newStopLoss = currentPrice - (TrailingStopPoints * _Point);
            //--- Move stop loss if position is profitable and the new SL is better.
            if(currentPrice > openPrice && newStopLoss > currentStopLoss)
              {
               trade.PositionModify(positionTicket, newStopLoss, PositionGetDouble(POSITION_TP));
              }
           }
         else if(positionType == POSITION_TYPE_SELL)
           {
            currentPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            newStopLoss = currentPrice + (TrailingStopPoints * _Point);
            //--- Move stop loss if position is profitable and the new SL is better.
            if(currentPrice < openPrice && (newStopLoss < currentStopLoss || currentStopLoss == 0))
              {
               trade.PositionModify(positionTicket, newStopLoss, PositionGetDouble(POSITION_TP));
              }
           }
        }
     }
}

//+------------------------------------------------------------------+
//| Manage Exit on Opposite Signal                                   |
//| Closes an open position if a valid counter-signal appears.       |
//+------------------------------------------------------------------+
void ManageExitOnOppositeSignal()
{
   //--- Exit if the feature is disabled by the user.
   if(!ExitOnOppositeSignal)
     {
      return;
     }

   //--- Check if a position is currently open for this symbol.
   if(PositionSelect(_Symbol))
     {
      long positionType = PositionGetInteger(POSITION_TYPE);

      //--- If it's a BUY position, check for a SELL signal to close it.
      if(positionType == POSITION_TYPE_BUY)
        {
         if(CheckSellCondition())
           {
            // Close the buy position and log the reason.
            trade.PositionClose(_Symbol, "Closed on opposite (sell) signal");
           }
        }
      //--- If it's a SELL position, check for a BUY signal to close it.
      else if(positionType == POSITION_TYPE_SELL)
        {
         if(CheckBuyCondition())
           {
            // Close the sell position and log the reason.
            trade.PositionClose(_Symbol, "Closed on opposite (buy) signal");
           }
        }
     }
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//| This is the main function that is called on every price change.  |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Validate Risk/Reward ratio from inputs. If it's not met, don't trade.
   if(StopLossATRMultiplier > 0 && (TakeProfitATRMultiplier / StopLossATRMultiplier) < MinRiskRewardRatio)
     {
      return;
     }

   //--- Manage open positions first (e.g., trailing stops).
   ManageTrailingStop();

   //--- New trade logic should only run once per bar to prevent over-trading.
   static datetime lastBarTime = 0;
   datetime currentBarTime = (datetime)SeriesInfoInteger(_Symbol, _Period, SERIES_LASTBAR_DATE);
   if(currentBarTime == lastBarTime)
     {
      return;
     }
   lastBarTime = currentBarTime;

   //--- Check for an early exit based on an opposite signal.
   ManageExitOnOppositeSignal();

   //--- Ensure only one trade is open per symbol using the efficient PositionSelect method.
   if(PositionSelect(_Symbol))
     {
      return; // Exit if a position for the current symbol already exists.
     }

   //--- Check for trading signals and execute trades.
   if(CheckBuyCondition())
     {
      double atrValue[];
      //--- Use ATR from the last completed bar for SL/TP calculation.
      if(CopyBuffer(ATR_Handle, 0, 1, 1, atrValue) > 0)
        {
         double stopLossPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK) - (atrValue[0] * StopLossATRMultiplier);
         double takeProfitPrice = SymbolInfoDouble(_Symbol, SYMBOL_ASK) + (atrValue[0] * TakeProfitATRMultiplier);
         double stopLossPoints = (SymbolInfoDouble(_Symbol, SYMBOL_ASK) - stopLossPrice);
         double lotSize = CalculateLotSize(stopLossPoints);
         string reason = "Buy Signal: HTF Trend Up, Local Trend Up, MACD Bullish Cross, RSI > 50";

         if(trade.Buy(lotSize, _Symbol, 0, stopLossPrice, takeProfitPrice, "Buy Signal: Trend & Momentum"))
           {
            LogTradeDetails("BUY", trade.ResultPrice(), lotSize, stopLossPrice, takeProfitPrice, reason);
           }
        }
     }
   else if(CheckSellCondition())
     {
      double atrValue[];
      if(CopyBuffer(ATR_Handle, 0, 1, 1, atrValue) > 0)
        {
         double stopLossPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID) + (atrValue[0] * StopLossATRMultiplier);
         double takeProfitPrice = SymbolInfoDouble(_Symbol, SYMBOL_BID) - (atrValue[0] * TakeProfitATRMultiplier);
         double stopLossPoints = (stopLossPrice - SymbolInfoDouble(_Symbol, SYMBOL_BID));
         double lotSize = CalculateLotSize(stopLossPoints);
         string reason = "Sell Signal: HTF Trend Down, Local Trend Down, MACD Bearish Cross, RSI < 50";

         if(trade.Sell(lotSize, _Symbol, 0, stopLossPrice, takeProfitPrice, "Sell Signal: Trend & Momentum"))
           {
            LogTradeDetails("SELL", trade.ResultPrice(), lotSize, stopLossPrice, takeProfitPrice, reason);
           }
        }
     }
}
//+------------------------------------------------------------------+
