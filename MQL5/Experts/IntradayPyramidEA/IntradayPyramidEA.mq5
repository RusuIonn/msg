//+------------------------------------------------------------------+
//|                                         IntradayPyramidEA.mq5|
//|                        Copyright 2023, Your Name/Company Name|
//|                                             https://www.mql5.com|
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, Your Name/Company Name"
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "EA intraday ce foloseste MA, RSI si ATR pentru a tranzactiona in directia trendului."

#include <Trade/Trade.mqh>

//--- Input Parameters
input group "Strategy Parameters"
input int       FastMAPeriod = 50;              // Perioada Medie Mobila Rapida
input int       SlowMAPeriod = 200;             // Perioada Medie Mobila Lenta
input int       RSIPeriod    = 14;              // Perioada RSI
input int       ATRPeriod    = 14;              // Perioada ATR

input group "Risk Management"
input double    LotSize      = 0.01;            // Marime Lot
input double    SL_ATR_Mult  = 2.0;             // Multiplicator ATR pentru Stop Loss
input double    TP_ATR_Mult  = 4.0;             // Multiplicator ATR pentru Take Profit
input int       MaxOpenTrades= 5;               // Numar maxim de tranzactii deschise

input group "EA Identification"
input long      MagicNumber  = 12345;           // Magic Number

//--- Global variables
CTrade trade;

//--- Indicator handles
int h_fast_ma;
int h_slow_ma;
int h_rsi;
int h_atr;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   //--- Initialize CTrade object
   trade.SetExpertMagicNumber(MagicNumber);
   trade.SetMarginMode();

   //--- Create indicator handles
   h_fast_ma = iMA(_Symbol, _Period, FastMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   h_slow_ma = iMA(_Symbol, _Period, SlowMAPeriod, 0, MODE_EMA, PRICE_CLOSE);
   h_rsi     = iRSI(_Symbol, _Period, RSIPeriod, PRICE_CLOSE);
   h_atr     = iATR(_Symbol, _Period, ATRPeriod);

   //--- Check for invalid handles
   if(h_fast_ma == INVALID_HANDLE || h_slow_ma == INVALID_HANDLE || h_rsi == INVALID_HANDLE || h_atr == INVALID_HANDLE)
     {
      Print("Error creating indicator handles. EA will not start.");
      return(INIT_FAILED);
     }

   Print("EA Initialized Successfully. Handles created.");
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   //--- Release indicator handles
   IndicatorRelease(h_fast_ma);
   IndicatorRelease(h_slow_ma);
   IndicatorRelease(h_rsi);
   IndicatorRelease(h_atr);
   Print("EA Deinitialized. Handles released.");
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   //--- Check for new bar
   static datetime last_bar_time;
   datetime current_bar_time = iTime(_Symbol, _Period, 0);

   if(last_bar_time != current_bar_time)
     {
      last_bar_time = current_bar_time;
      CheckForNewTrade();
     }
  }

//+------------------------------------------------------------------+
//| Check for new trade signals                                      |
//+------------------------------------------------------------------+
void CheckForNewTrade()
  {
   //--- Get indicator values
   double fast_ma_arr[1];
   double slow_ma_arr[1];
   double rsi_arr[2]; // Index 0 for bar[2], Index 1 for bar[1]

   //--- Copy the indicator values from the last closed bars
   // CopyBuffer copies data chronologically by default (index 0 is oldest)
   if(CopyBuffer(h_fast_ma, 0, 1, 1, fast_ma_arr) < 1 ||
      CopyBuffer(h_slow_ma, 0, 1, 1, slow_ma_arr) < 1 ||
      CopyBuffer(h_rsi, 0, 1, 2, rsi_arr) < 2)
     {
      Print("Error copying indicator buffers");
      return;
     }

   //--- Define Trend Direction (based on the last closed bar: index 1)
   bool isUptrend = (fast_ma_arr[0] > slow_ma_arr[0]);
   bool isDowntrend = (fast_ma_arr[0] < slow_ma_arr[0]);

   //--- Define Entry Signal (RSI Crossover)
   // rsi_arr[0] holds the value for bar index 2 (older bar)
   // rsi_arr[1] holds the value for bar index 1 (newer, just closed bar)
   bool buySignal = isUptrend && (rsi_arr[0] < 50 && rsi_arr[1] >= 50);
   bool sellSignal = isDowntrend && (rsi_arr[0] > 50 && rsi_arr[1] <= 50);

   //--- Check pyramiding rules
   if(CountOpenTrades() >= MaxOpenTrades)
     {
      return; // Max trades limit reached
     }

   //--- Open new trade if signal is present
   if(buySignal)
     {
      OpenNewTrade(ORDER_TYPE_BUY);
     }
   else if(sellSignal)
     {
      OpenNewTrade(ORDER_TYPE_SELL);
     }
  }

//+------------------------------------------------------------------+
//| Count currently open trades for this EA/symbol                   |
//+------------------------------------------------------------------+
int CountOpenTrades()
  {
   int count = 0;
   for(int i = 0; i < PositionsTotal(); i++)
     {
      ulong ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(ticket))
        {
         if(PositionGetString(POSITION_SYMBOL) == _Symbol &&
            PositionGetInteger(POSITION_MAGIC) == MagicNumber)
           {
            count++;
           }
        }
     }
   return count;
  }

//+------------------------------------------------------------------+
//| Open a new trade                                                 |
//+------------------------------------------------------------------+
void OpenNewTrade(ENUM_ORDER_TYPE order_type)
  {
   //--- Get ATR value for SL/TP calculation (from the last closed bar)
   double atr_val_arr[1];
   if(CopyBuffer(h_atr, 0, 1, 1, atr_val_arr) < 1)
     {
      Print("Error copying ATR buffer for SL/TP calculation.");
      return;
     }
   double atr_value = atr_val_arr[0];

   //--- Get current prices
   MqlTick latest_tick;
   if(!SymbolInfoTick(_Symbol, latest_tick))
     {
      Print("Could not retrieve latest tick. Trade aborted.");
      return;
     }
   double ask_price = latest_tick.ask;
   double bid_price = latest_tick.bid;

   //--- Calculate SL and TP
   double sl_price = 0;
   double tp_price = 0;

   if(order_type == ORDER_TYPE_BUY)
     {
      sl_price = ask_price - (atr_value * SL_ATR_Mult);
      tp_price = ask_price + (atr_value * TP_ATR_Mult);
     }
   else // SELL
     {
      sl_price = bid_price + (atr_value * SL_ATR_Mult);
      tp_price = bid_price - (atr_value * TP_ATR_Mult);
     }

   //--- Normalize SL/TP to broker requirements
   sl_price = NormalizeDouble(sl_price, _Digits);
   tp_price = NormalizeDouble(tp_price, _Digits);

   //--- Send trade request
   Print("Attempting to open ", EnumToString(order_type), " trade. SL: ", sl_price, " TP: ", tp_price);
   bool result = false;
   if(order_type == ORDER_TYPE_BUY)
     {
      result = trade.Buy(LotSize, _Symbol, ask_price, sl_price, tp_price, "IntradayPyramidEA Buy");
     }
   else if(order_type == ORDER_TYPE_SELL)
     {
      result = trade.Sell(LotSize, _Symbol, bid_price, sl_price, tp_price, "IntradayPyramidEA Sell");
     }

   //--- Check result
   if(result)
     {
      Print("Trade opened successfully. Position Ticket: ", trade.ResultPosition());
     }
   else
     {
      Print("Error opening trade. Code: ", trade.ResultRetcode(), ". Message: ", trade.ResultComment());
     }
  }
//+------------------------------------------------------------------+
