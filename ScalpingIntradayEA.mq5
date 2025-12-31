//+------------------------------------------------------------------+
//|                                       ScalpingIntradayEA.mq5 |
//|                      Copyright 2023, Your Name/Company |
//|                                      http://www.example.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Your Name/Company"
#property link      "http://www.example.com"
#property version   "1.00"
#property description "Scalping and Intraday Expert Advisor based on MA, RSI, and ATR."

//--- Include Trade Library
#include <Trade/Trade.mqh>

//--- EA Input Parameters

//--- Moving Averages
input int      FastMA_Period   = 10;           // Fast MA Period
input int      SlowMA_Period   = 25;           // Slow MA Period
input ENUM_MA_METHOD MA_Method = MODE_SMA;   // MA Method
input ENUM_APPLIED_PRICE Applied_Price = PRICE_CLOSE; // Applied Price

//--- RSI
input int      RSI_Period      = 14;           // RSI Period
input double   RSI_Oversold    = 30;           // RSI Oversold Level
input double   RSI_Overbought  = 70;           // RSI Overbought Level
input ENUM_APPLIED_PRICE RSI_Applied_Price = PRICE_CLOSE; // RSI Applied Price

//--- ATR for Stop Loss and Take Profit
input int      ATR_Period      = 14;           // ATR Period
input double   SL_ATR_Multiplier = 2.0;        // Stop Loss ATR Multiplier
input double   TP_ATR_Multiplier = 3.0;        // Take Profit ATR Multiplier

//--- Trade Management
input double   LotSize         = 0.01;         // Fixed Lot Size
input ulong    MagicNumber     = 12345;        // EA's Magic Number

//--- Trailing Stop
input bool     EnableTrailingStop = true;      // Enable Trailing Stop
input int      TrailingStopTrigger = 200;      // Trailing Stop Trigger (in Points)
input int      TrailingStopStep    = 50;       // Trailing Stop Step (in Points)

//--- Global Variables
CTrade     trade;                  // Trade object
int        fast_ma_handle;         // Fast MA handle
int        slow_ma_handle;         // Slow MA handle
int        rsi_handle;             // RSI handle
int        atr_handle;             // ATR handle
datetime   last_bar_time;          // To check for a new bar

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
   //--- Initialize indicator handles
   fast_ma_handle = iMA(_Symbol, _Period, FastMA_Period, 0, MA_Method, Applied_Price);
   slow_ma_handle = iMA(_Symbol, _Period, SlowMA_Period, 0, MA_Method, Applied_Price);
   rsi_handle = iRSI(_Symbol, _Period, RSI_Period, RSI_Applied_Price);
   atr_handle = iATR(_Symbol, _Period, ATR_Period);

   //--- Check if handles are valid
   if(fast_ma_handle == INVALID_HANDLE || slow_ma_handle == INVALID_HANDLE ||
      rsi_handle == INVALID_HANDLE || atr_handle == INVALID_HANDLE)
     {
      Print("Error creating indicator handles. EA will not work.");
      return(INIT_FAILED);
     }

   //--- Initialize trade object
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetMarginMode();
   trade.SetTypeFillingBySymbol(_Symbol);

   //--- Initialize last bar time
   last_bar_time = 0;

   Print("EA Initialized Successfully.");
   return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //--- Release indicator handles
   IndicatorRelease(fast_ma_handle);
   IndicatorRelease(slow_ma_handle);
   IndicatorRelease(rsi_handle);
   IndicatorRelease(atr_handle);

   Print("EA Deinitialized.");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
   //--- Check for a new bar
   MqlRates rates[1];
   if(CopyRates(_Symbol, _Period, 0, 1, rates) < 1)
   {
      Print("Could not copy rates. Skipping tick.");
      return;
   }

   if(rates[0].time > last_bar_time)
   {
      last_bar_time = rates[0].time;

      //--- Main logic starts here, executed once per bar ---

      //--- Indicator buffers
      double fast_ma_buffer[2];
      double slow_ma_buffer[2];
      double rsi_buffer[2];
      double atr_buffer[1];

      //--- Copy new indicator values
      if(CopyBuffer(fast_ma_handle, 0, 1, 2, fast_ma_buffer) < 2 ||
         CopyBuffer(slow_ma_handle, 0, 1, 2, slow_ma_buffer) < 2 ||
         CopyBuffer(rsi_handle, 0, 1, 2, rsi_buffer) < 2 ||
         CopyBuffer(atr_handle, 0, 1, 1, atr_buffer) < 1)
      {
         Print("Error copying indicator buffers. Skipping this tick.");
         return;
      }

      //--- Get values from indicator buffers. Bar 1 is the most recently closed bar.
      double fast_ma_bar1 = fast_ma_buffer[0];
      double fast_ma_bar2 = fast_ma_buffer[1];
      double slow_ma_bar1 = slow_ma_buffer[0];
      double slow_ma_bar2 = slow_ma_buffer[1];
      double rsi_bar1 = rsi_buffer[0];
      double atr_bar1 = atr_buffer[0];

      //--- === Main Logic === ---

      //--- Manage trailing stop for any open positions first
      ManageTrailingStop();

      //--- Check for trading signals only if there are no open positions for this EA on this symbol
      if(!HasOpenPosition())
      {
         //--- Check for Buy Signal
         if(CheckBuySignal(fast_ma_bar1, fast_ma_bar2, slow_ma_bar1, slow_ma_bar2, rsi_bar1))
         {
            OpenTrade(ORDER_TYPE_BUY, atr_bar1);
         }
         //--- Check for Sell Signal
         else if(CheckSellSignal(fast_ma_bar1, fast_ma_bar2, slow_ma_bar1, slow_ma_bar2, rsi_bar1))
         {
            OpenTrade(ORDER_TYPE_SELL, atr_bar1);
         }
      }
   }
}

//+------------------------------------------------------------------+
//| Check if EA has an open position on the current symbol           |
//+------------------------------------------------------------------+
bool HasOpenPosition()
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      if(PositionSelectByIndex(i))
      {
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            return(true); // Found our position
         }
      }
   }
   return(false); // No position found
}

//+------------------------------------------------------------------+
//| Check for Buy Signal                                             |
//+------------------------------------------------------------------+
bool CheckBuySignal(double fast_ma_b1, double fast_ma_b2, double slow_ma_b1, double slow_ma_b2, double rsi_b1)
{
   //--- Condition 1: Fast MA crossed above Slow MA
   bool crossover = (fast_ma_b2 < slow_ma_b2) && (fast_ma_b1 > slow_ma_b1);

   //--- Condition 2: RSI is below the oversold level
   bool rsi_check = (rsi_b1 < RSI_Oversold);

   return (crossover && rsi_check);
}

//+------------------------------------------------------------------+
//| Check for Sell Signal                                            |
//+------------------------------------------------------------------+
bool CheckSellSignal(double fast_ma_b1, double fast_ma_b2, double slow_ma_b1, double slow_ma_b2, double rsi_b1)
{
   //--- Condition 1: Fast MA crossed below Slow MA
   bool crossunder = (fast_ma_b2 > slow_ma_b2) && (fast_ma_b1 < slow_ma_b1);

   //--- Condition 2: RSI is above the overbought level
   bool rsi_check = (rsi_b1 > RSI_Overbought);

   return (crossunder && rsi_check);
}

//+------------------------------------------------------------------+
//| Open a new trade                                                 |
//+------------------------------------------------------------------+
void OpenTrade(ENUM_ORDER_TYPE type, double atr_value)
{
   //--- Get current market prices
   double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   //--- Calculate Stop Loss and Take Profit based on ATR
   double sl_points = atr_value * SL_ATR_Multiplier;
   double tp_points = atr_value * TP_ATR_Multiplier;

   double stop_loss = 0;
   double take_profit = 0;
   double price = 0;

   if(type == ORDER_TYPE_BUY)
   {
      price = ask;
      stop_loss = price - sl_points;
      take_profit = price + tp_points;
   }
   else if(type == ORDER_TYPE_SELL)
   {
      price = bid;
      stop_loss = price + sl_points;
      take_profit = price - tp_points;
   }

   //--- Normalize SL/TP to the correct digit precision
   stop_loss = NormalizeDouble(stop_loss, _Digits);
   take_profit = NormalizeDouble(take_profit, _Digits);

   //--- Send the trade request
   bool result = trade.PositionOpen(_Symbol, type, LotSize, price, stop_loss, take_profit);
   if(!result)
   {
      Print("Error opening position: ", trade.ResultGetLastRetcode(), " - ", trade.ResultGetLastRetcodeDescription());
   }
   else
   {
      Print("Position opened successfully.");
   }
}

//+------------------------------------------------------------------+
//| Manage Trailing Stop for open positions                          |
//+------------------------------------------------------------------+
void ManageTrailingStop()
{
   if(!EnableTrailingStop)
      return;

   double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);

   //--- Iterate through all open positions
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      //--- Select a position
      if(PositionSelectByIndex(i))
      {
         //--- Check if it's our EA's position for the current symbol
         if(PositionGetInteger(POSITION_MAGIC) == MagicNumber && PositionGetString(POSITION_SYMBOL) == _Symbol)
         {
            ulong ticket = PositionGetInteger(POSITION_TICKET);
            long type = PositionGetInteger(POSITION_TYPE);
            double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
            double current_price = (type == POSITION_TYPE_BUY) ? SymbolInfoDouble(_Symbol, SYMBOL_BID) : SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double current_sl = PositionGetDouble(POSITION_SL);

            double new_sl = 0;
            double trigger_level = TrailingStopTrigger * point;

            if(type == POSITION_TYPE_BUY) //--- For BUY positions
            {
               if(current_price - open_price > trigger_level)
               {
                  new_sl = current_price - (TrailingStopStep * point);
                  //--- We only move SL forward
                  if(current_sl < new_sl || current_sl == 0)
                  {
                     trade.PositionModify(ticket, NormalizeDouble(new_sl, _Digits), PositionGetDouble(POSITION_TP));
                  }
               }
            }
            else if(type == POSITION_TYPE_SELL) //--- For SELL positions
            {
               if(open_price - current_price > trigger_level)
               {
                  new_sl = current_price + (TrailingStopStep * point);
                  //--- We only move SL forward
                  if(current_sl > new_sl || current_sl == 0)
                  {
                     trade.PositionModify(ticket, NormalizeDouble(new_sl, _Digits), PositionGetDouble(POSITION_TP));
                  }
               }
            }
         }
      }
   }
}
