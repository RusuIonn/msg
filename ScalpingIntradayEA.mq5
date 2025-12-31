//+------------------------------------------------------------------+
//|                                     ScalpingIntradayEA.mq5 |
//|                      Copyright 2023, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2023, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"
#property version   "1.00"
#property description "Expert Advisor pentru Scalping si Intraday bazat pe Medii Mobile, RSI si ATR."

//--- Include-uri
#include <Trade/Trade.mqh>

//--- Parametri de intrare (Inputs)
sinput group "Parametri Medii Mobile"
input int      FastMA_Period = 10;      // Perioada Mediei Mobile Rapide
input int      SlowMA_Period = 21;      // Perioada Mediei Mobile Lente
input ENUM_MA_METHOD MA_Method = MODE_EMA;  // Metoda de calcul a Mediei Mobile
input ENUM_APPLIED_PRICE MA_Applied_Price = PRICE_CLOSE; // Pretul aplicat

sinput group "Parametri RSI"
input int      RSI_Period = 14;         // Perioada RSI
input double   RSI_Overbought = 70.0;   // Nivel Supracumparare RSI
input double   RSI_Oversold = 30.0;     // Nivel Supravanzare RSI
input ENUM_APPLIED_PRICE RSI_Applied_Price = PRICE_CLOSE; // Pretul aplicat

sinput group "Managementul Riscului (ATR)"
input int      ATR_Period = 14;         // Perioada ATR
input double   ATR_Multiplier_SL = 2.0; // Multiplicator ATR pentru Stop Loss
input double   ATR_Multiplier_TP = 4.0; // Multiplicator ATR pentru Take Profit

sinput group "Managementul Tranzactiilor"
input double   LotSize = 0.01;          // Marimea Lotului
input ulong    MagicNumber = 12345;     // Numarul Magic al EA-ului
input int      TrailingStop = 30;       // Pasi Trailing Stop (0 = dezactivat)

//--- Handle-uri pentru indicatori
int h_FastMA;
int h_SlowMA;
int h_RSI;
int h_ATR;

//--- Instanta CTrade pentru operatiuni de tranzactionare
CTrade trade;

//--- Functia de initializare a expertului
int OnInit()
  {
   //--- Seteaza numarul magic pentru CTrade
   trade.SetExpertMagicNumber(MagicNumber);

   //--- Obtine handle pentru Media Mobila Rapida
   h_FastMA = iMA(_Symbol, _Period, FastMA_Period, 0, MA_Method, MA_Applied_Price);
   if(h_FastMA == INVALID_HANDLE)
     {
      Print("Eroare la crearea handle-ului pentru Media Mobila Rapida. Cod eroare: ", GetLastError());
      return(INIT_FAILED);
     }

   //--- Obtine handle pentru Media Mobila Lenta
   h_SlowMA = iMA(_Symbol, _Period, SlowMA_Period, 0, MA_Method, MA_Applied_Price);
   if(h_SlowMA == INVALID_HANDLE)
     {
      Print("Eroare la crearea handle-ului pentru Media Mobila Lenta. Cod eroare: ", GetLastError());
      return(INIT_FAILED);
     }

   //--- Obtine handle pentru RSI
   h_RSI = iRSI(_Symbol, _Period, RSI_Period, RSI_Applied_Price);
   if(h_RSI == INVALID_HANDLE)
     {
      Print("Eroare la crearea handle-ului pentru RSI. Cod eroare: ", GetLastError());
      return(INIT_FAILED);
     }

   //--- Obtine handle pentru ATR
   h_ATR = iATR(_Symbol, _Period, ATR_Period);
   if(h_ATR == INVALID_HANDLE)
     {
      Print("Eroare la crearea handle-ului pentru ATR. Cod eroare: ", GetLastError());
      return(INIT_FAILED);
     }

   //--- Initializare reusita
   Print("Expert Advisor initializat cu succes.");
   return(INIT_SUCCEEDED);
  }

//--- Functia de deinitializare a expertului
void OnDeinit(const int reason)
  {
   //--- Elibereaza resursele alocate indicatorilor
   IndicatorRelease(h_FastMA);
   IndicatorRelease(h_SlowMA);
   IndicatorRelease(h_RSI);
   IndicatorRelease(h_ATR);
   Print("Expert Advisor deinitializat.");
  }

void HandleTrailingStop();
void CheckForNewTrade();

//--- Functia tick a expertului
void OnTick()
  {
   //--- Managementul Trailing Stop ruleaza la fiecare tick
   HandleTrailingStop();

   //--- Logica de intrare in tranzactie ruleaza doar pe o bara noua
   CheckForNewTrade();
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Verifica si executa o noua tranzactie.                           |
//+------------------------------------------------------------------+
void CheckForNewTrade()
  {
   //--- Functie helper pentru verificarea unei bare noi
   static datetime last_bar_time = 0;
   datetime current_bar_time = iTime(_Symbol, _Period, 0);

   if(current_bar_time == last_bar_time)
     {
      return; // Nu este o bara noua
     }
   last_bar_time = current_bar_time;

   //--- Executa tranzactiile doar daca nu exista pozitii deschise
   if(PositionsTotal() > 0)
     {
      return;
     }

   //--- Defineste array-urile pentru a stoca datele indicatorilor
   double arr_FastMA[3], arr_SlowMA[3], arr_RSI[2], arr_ATR[2]; // ATR size increased to 2

   //--- Seteaza array-urile ca serii de timp (index 0 = bara curenta)
   ArraySetAsSeries(arr_FastMA, true);
   ArraySetAsSeries(arr_SlowMA, true);
   ArraySetAsSeries(arr_RSI, true);
   ArraySetAsSeries(arr_ATR, true);

   //--- Obtine valorile indicatorilor
   if(CopyBuffer(h_FastMA, 0, 1, 3, arr_FastMA) <= 0 || CopyBuffer(h_SlowMA, 0, 1, 3, arr_SlowMA) <= 0 ||
      CopyBuffer(h_RSI, 0, 1, 2, arr_RSI) <= 0 || CopyBuffer(h_ATR, 0, 1, 1, arr_ATR) <= 0)
     {
      Print("Eroare la copierea datelor din bufferele indicatorilor: ", GetLastError());
      return;
     }

   //--- Conditii de Crossover pentru intrare
   // Index [0] = cea mai recenta bara inchisa; Index [1] = bara de dinainte
   bool buy_crossover = arr_FastMA[0] > arr_SlowMA[0] && arr_FastMA[1] <= arr_SlowMA[1];
   bool sell_crossover = arr_FastMA[0] < arr_SlowMA[0] && arr_FastMA[1] >= arr_SlowMA[1];

   //--- Semnale finale, combinate cu filtrul RSI
   bool buy_signal = buy_crossover && arr_RSI[0] < RSI_Oversold;
   bool sell_signal = sell_crossover && arr_RSI[0] > RSI_Overbought;

   //--- Calculeaza valoarea ATR de pe bara semnalului
   double atr_value = arr_ATR[0];

   if(buy_signal)
     {
      double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double stop_loss_price = entry_price - atr_value * ATR_Multiplier_SL;
      double take_profit_price = entry_price + atr_value * ATR_Multiplier_TP;
      if(trade.Buy(LotSize, _Symbol, entry_price, stop_loss_price, take_profit_price, "Buy Signal"))
        {
         Print("Tranzactie BUY deschisa: ", trade.ResultDeal(), " la pretul ", trade.ResultPrice());
        }
      else
        {
         Print("Eroare la deschiderea tranzactiei BUY: ", trade.ResultRetcodeDescription());
        }
     }
   else if(sell_signal)
     {
      double entry_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      double stop_loss_price = entry_price + atr_value * ATR_Multiplier_SL;
      double take_profit_price = entry_price - atr_value * ATR_Multiplier_TP;
      if(trade.Sell(LotSize, _Symbol, entry_price, stop_loss_price, take_profit_price, "Sell Signal"))
        {
         Print("Tranzactie SELL deschisa: ", trade.ResultDeal(), " la pretul ", trade.ResultPrice());
        }
      else
        {
         Print("Eroare la deschiderea tranzactiei SELL: ", trade.ResultRetcodeDescription());
        }
     }
  }

//+------------------------------------------------------------------+
//| Gestioneaza Trailing Stop pentru pozitiile deschise.             |
//+------------------------------------------------------------------+
void HandleTrailingStop()
  {
   //--- Verifica daca Trailing Stop este activat
   if(TrailingStop <= 0)
      return;

   //--- Itereaza prin toate pozitiile deschise
   for(int i = PositionsTotal() - 1; i >= 0; i--)
     {
      //--- Selecteaza pozitia si verifica daca apartine acestui EA
      ulong position_ticket = PositionGetTicket(i);
      if(PositionSelectByTicket(position_ticket) &&
         PositionGetInteger(POSITION_MAGIC) == MagicNumber &&
         PositionGetString(POSITION_SYMBOL) == _Symbol)
        {
         long position_type = PositionGetInteger(POSITION_TYPE);
         double open_price = PositionGetDouble(POSITION_PRICE_OPEN);
         double current_sl = PositionGetDouble(POSITION_SL);
         double trailing_stop_dist = TrailingStop * _Point;

         //--- Gestioneaza Trailing Stop pentru pozitiile de BUY
         if(position_type == POSITION_TYPE_BUY)
           {
            double current_price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
            double new_sl = current_price - trailing_stop_dist;

            //--- Conditii pentru a muta SL-ul
            if(new_sl > open_price && (current_sl < new_sl || current_sl == 0))
              {
               if(trade.PositionModify(position_ticket, new_sl, PositionGetDouble(POSITION_TP)))
                 {
                  Print("Trailing Stop mutat pentru pozitia BUY #", position_ticket, " la ", new_sl);
                 }
              }
           }
         //--- Gestioneaza Trailing Stop pentru pozitiile de SELL
         else if(position_type == POSITION_TYPE_SELL)
           {
            double current_price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
            double new_sl = current_price + trailing_stop_dist;

            //--- Conditii pentru a muta SL-ul
            if(new_sl < open_price && (current_sl > new_sl || current_sl == 0))
              {
               if(trade.PositionModify(position_ticket, new_sl, PositionGetDouble(POSITION_TP)))
                 {
                  Print("Trailing Stop mutat pentru pozitia SELL #", position_ticket, " la ", new_sl);
                 }
              }
           }
        }
     }
  }
