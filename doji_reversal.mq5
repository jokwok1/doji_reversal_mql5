//+------------------------------------------------------------------+
//|                                           Doji Reversal Strategy |
//|                                                        Tan Jacky |
//|                                       https://github.com/jokwok1 |
//+------------------------------------------------------------------+
//|                                                  Version Notes 1 |
//| Skeleton of trading Strategy                                     |
//|                                                                  |
//| relook the KAMA for more accurate entries                        |
//|                                                                  |
//+------------------------------------------------------------------+
//|                                                    Patch Notes 1 |
//|doji candle, Close>EMA, RSI oversold for long                     |
//|Opposite for shorts                                               |
//|1.5x ATR Take Profit, 1x ATR Stop Loss                              |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Tan Jacky"
#property link      "https://www.mql5.com"
#property version   "1.00"

//Include Functions
#include <Trade\Trade.mqh> //Include MQL trade object functions
CTrade   *Trade;           //Declaire Trade as pointer to CTrade class

//Setup Variables
input int                InpMagicNumber  = 2000002;     //Unique identifier for this expert advisor
input string             InpTradeComment = __FILE__;    //Optional comment for trades
input ENUM_APPLIED_PRICE InpAppliedPrice = PRICE_CLOSE; //Applied price for indicators
input int                MinDelay        = 4;           //Delay in minutes of trade open and candle open

//Global Variables
string          IndicatorMetrics    = "";
int             TicksReceivedCount  = 0; //Counts the number of ticks from oninit function
int             TicksProcessedCount = 0; //Counts the number of ticks proceeded from oninit function based off candle opens only
static datetime TimeLastTickProcessed;   //Stores the last time a tick was processed based off candle opens only

//Store Position Ticket Number
ulong  TicketNumber = 0;
ulong  TicketNumber2 = 0;

// Magic No. for Multiple trades
int Magic1 = 0;
int Magic2 = 0;

//Risk Metrics
input bool   TslCheck          = true;   //Use Trailing Stop Loss?
input bool   RiskCompounding   = false;  //Use Compounded Risk Method?
double       StartingEquity    = 0.0;    //Starting Equity
double       CurrentEquityRisk = 0.0;    //Equity that will be risked per trade
input double MaxLossPrc        = 0.02;   //Percent Risk Per Trade
input double AtrProfitMulti    = 1.5;    //ATR Profit Multiple
input double AtrLossMulti      = 1.0;    //ATR Loss Multiple

//ATR Handle and Variables
int HandleAtr;
int AtrPeriod  = 14;

//Doji Candle Variables
input bool   C1_Check_Conf     = true;   //|--- Doji Candle Check ---| 
input double ATR_Doji_Multi    = 1.2;    // ATR multiple required for wicks distance
input double Percent_Doji_Body = 20;     // Percent body size of wicks
// C1 Buffer Numbers 
const string C1Name        = "Doji"; 

//EMA Handle and Variables
input bool   C2_Check_Conf = true;   //|--- C2 CHECK ---| 
int HandleEma;
input int    EmaPeriod     = 200;
bool         C2_L_Check    = false;    
bool         C2_S_Check    = false;  
const string C2Name        = "EMA"; 


//RSI Handle and Variables
input bool   C3_Check_Conf = true;   //|--- C3 RSI CHECK ---| 
int HandleRsi;
input int    RsiPeriod     = 14;
input double RsiOverbought = 70.0;   // Overbought levels for RSI
input double RsiOversold   = 30.0;   // Oversold levels for RSI
bool         C3_L_Check    = false;    
bool         C3_S_Check    = false;  
bool         C3_L_Exit    = false;    
bool         C3_S_Exit    = false; 
const string C3Name        = "RSI"; 

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   //Declare magic number for all trades
   Trade = new CTrade();

   //Store starting equity onInit
   StartingEquity  = AccountInfoDouble(ACCOUNT_EQUITY);
   
   // Set up handle for ATR indicator on the initialisation of expert
   HandleAtr = iATR(Symbol(),Period(),AtrPeriod);
   Print("Handle for ATR /", Symbol()," / ", EnumToString(Period()),"successfully created");
   
   //Set up handle for EMA indicator on the oninit
   HandleEma = iMA(Symbol(),Period(),EmaPeriod,0,MODE_EMA,InpAppliedPrice);
   Print("Handle for EMA /", Symbol()," / ", EnumToString(Period()),"successfully created");
   
   //Set up handle for EMA indicator on the oninit
   HandleRsi = iRSI(Symbol(),Period(),RsiPeriod,InpAppliedPrice);
   Print("Handle for RSI /", Symbol()," / ", EnumToString(Period()),"successfully created");
   
   return(INIT_SUCCEEDED);
   
   Magic1 = InpMagicNumber;
   Magic2 = Magic1 + 1;

  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
   //Remove indicator handle from Metatrader Cache
   IndicatorRelease(HandleAtr);
   IndicatorRelease(HandleEma);
   IndicatorRelease(HandleRsi);
   Print("Handle released");
}
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
//---
   //Counts the number of ticks received  
   TicksReceivedCount++; 
   
   //Checks for new candle
   bool IsNewCandle = false;
   if(TimeLastTickProcessed != iTime(Symbol(),Period(),0))
   {
      IsNewCandle = true;
      TimeLastTickProcessed=iTime(Symbol(),Period(),0);
   }
   
   //If there is a new candle, process any trades
   if(IsNewCandle == true)
   {
      //Counts the number of ticks processed
      TicksProcessedCount++;

      //Check if position is still open. If not open, return 0.
      if (!PositionSelectByTicket(TicketNumber) && !PositionSelectByTicket(TicketNumber2)) {
         TicketNumber = 0;
         TicketNumber2 = 0;
    } 
   
      //Initiate String for indicatorMetrics Variable. This will reset variable each time OnTick function runs.
      IndicatorMetrics ="";  
      StringConcatenate(IndicatorMetrics,Symbol()," | Last Processed: ",TimeLastTickProcessed," | Open Ticket: ", TicketNumber);
   
      //Money Management - ATR
      double CurrentAtr = GetATRValue(); //Gets ATR value double using custom function - convert double to string as per symbol digits
      StringConcatenate(IndicatorMetrics, IndicatorMetrics, " | ATR: ", CurrentAtr);
   
      //Strategy Trigger - MACD
      string OpenSignalDoji = GetDojiOpenSignal(CurrentAtr,Percent_Doji_Body,ATR_Doji_Multi); //Variable will return Long or Short Bias only doji candle
      StringConcatenate(IndicatorMetrics, IndicatorMetrics, " | Doji: ", OpenSignalDoji); //Concatenate indicator values to output comment for user   
   
      //Strategy Filter - EMA
      string OpenSignalEma = GetEmaOpenSignal(); //Variable will return long or short bias if close is above or below EMA.
      StringConcatenate(IndicatorMetrics, IndicatorMetrics, " | EMA Bias: ", OpenSignalEma); //Concatenate indicator values to output comment for user
      
      //Strategy Filter - RSI
      string OpenSignalRsi = GetRsiOpenSignal(RsiOverbought,RsiOversold); //Variable will return long or short bias depending on RSI levels
      StringConcatenate(IndicatorMetrics, IndicatorMetrics, " | RSI Bias: ", OpenSignalRsi);
      
      //EMA Confirmation Check, if C2 Check is false, no EMA filter used
      if (OpenSignalEma == "Long" || C2_Check_Conf == false)
         C2_L_Check = true; 
      else 
         C2_L_Check = false;
      if (OpenSignalEma == "Short" || C2_Check_Conf == false)
         C2_S_Check = true;  
      else 
         C2_S_Check = false;
         
      //RSI Confirmation Check, if C2 Check is false
      if (OpenSignalRsi == "Long" || C3_Check_Conf == false)
         C3_L_Check = true; 
      else 
         C3_L_Check = false;
      if (OpenSignalRsi == "Short" || C3_Check_Conf == false)
         C3_S_Check = true;  
      else 
         C3_S_Check = false;
         
      // Exit code 
      if (C3_Check_Conf == true && OpenSignalRsi == "Long Exit") 
         C3_L_Exit = true;
      else 
         C3_L_Exit = false; 
      if (C3_Check_Conf == true && OpenSignalRsi == "Short Exit") 
         C3_S_Exit = true;
      else 
         C3_S_Exit = false;   
      
         
      //Check if any Long / Short Trades are open
      bool checkLong  = IsLongTradeOpen(); 
      bool checkShort = IsShortTradeOpen();   
      
      //Trade Entries Population
      bool            LongEntry = false; // This is used to determine standard entries based on C1 and OCR
      bool            ShortEntry = false; // have to recall on every new candle
      int totalTrades = CheckTrades();   
      
       //Enter trades and return position ticket number
      if (Period() >= PERIOD_D1){  //checks if the period is less than the daily TF, if not, delay added to ensure trades entered during trade Open
         while(TimeCurrent() <= iTime(Symbol(),Period(),0) + (MinDelay*60)) 
            Sleep(1000); // delay by 4 mins which give the trading open for daily TF
      }
      
      if (C3_L_Exit == true && checkLong == true)
         if (totalTrades == 2){
            ProcessTradeClose();
            ProcessTradeClose();
         }
         else if (totalTrades == 1)
               ProcessTradeClose();
      if (C3_S_Exit == true && checkShort == true)
         if (totalTrades == 2){
            ProcessTradeClose();
            ProcessTradeClose();
         }
         else if (totalTrades == 1)
            ProcessTradeClose(); 
      
      totalTrades = CheckTrades();
      
      
      if(OpenSignalDoji == "Doji" && C2_L_Check == true && C3_L_Check == true && totalTrades <= 0)
         LongEntry = true;
      else if (OpenSignalDoji == "Doji" && C2_S_Check == true && C3_S_Check == true && totalTrades <= 0)
         ShortEntry = true;
      
      if(LongEntry == true) {
         ProcessTradeClose();
         if(TslCheck == true) { // 2 Trades Entered for Break Even and Trailing Stop Loss Functionality
            TicketNumber = ProcessTradeOpen(ORDER_TYPE_BUY,CurrentAtr,1, Magic1);
            TicketNumber2 = ProcessTradeOpen(ORDER_TYPE_BUY,CurrentAtr,0, Magic2);
         } else if(TslCheck == false) {
            TicketNumber = ProcessTradeOpen(ORDER_TYPE_BUY,CurrentAtr,1, Magic1);
            TicketNumber2 = ProcessTradeOpen(ORDER_TYPE_BUY,CurrentAtr,1, Magic2); 
         }
      }   
      else if(ShortEntry == true) {
         ProcessTradeClose();
         if(TslCheck == true) { // 2 Trades Entered for Break Even and Trailing Stop Loss Functionality
            TicketNumber = ProcessTradeOpen(ORDER_TYPE_SELL,CurrentAtr,1, Magic1); 
            TicketNumber2 = ProcessTradeOpen(ORDER_TYPE_SELL,CurrentAtr,0, Magic2);
         } else if(TslCheck == false) {  
            TicketNumber = ProcessTradeOpen(ORDER_TYPE_SELL,CurrentAtr,1, Magic1); 
            TicketNumber2 = ProcessTradeOpen(ORDER_TYPE_SELL,CurrentAtr,1, Magic2);   
         }
      }
      //Adjust Open Positions - Trailing Stop Loss
      if(TslCheck == true)
         AdjustTsl(TicketNumber2, CurrentAtr, AtrLossMulti, Magic2, totalTrades);
  }
  
   //Comment for user
   Comment("\n\rExpert: ", InpMagicNumber, "\n\r",
         "MT5 Server Time: ", TimeCurrent(), "\n\r",
         "Ticks Received: ", TicksReceivedCount,"\n\r",
         "Ticks Processed: ", TicksProcessedCount,"\n\r"
         "Symbols Traded: \n\r", 
         IndicatorMetrics);       
}
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Custom function                                                  |
//+------------------------------------------------------------------+
//Custom Function to get ATR value
double GetATRValue()
{
   //Set symbol string and indicator buffers
   string    CurrentSymbol   = Symbol();
   const int StartCandle     = 0;
   const int RequiredCandles = 3; //How many candles are required to be stored in Expert 

   //Indicator Variables and Buffers
   const int IndexAtr        = 0; //ATR Value
   double    BufferAtr[];         //[prior,current confirmed,not confirmed] 

   //Populate buffers for ATR Value; check errors
   bool FillAtr = CopyBuffer(HandleAtr,IndexAtr,StartCandle,RequiredCandles,BufferAtr); //Copy buffer uses oldest as 0 (reversed)
   if(FillAtr==false)return(0);

   //Find ATR Value for Candle '1' Only
   double CurrentAtr   = NormalizeDouble(BufferAtr[1],5);

   //Return ATR Value
   return(CurrentAtr);
}

//Custom Function to get MACD signals
string GetDojiOpenSignal(double CurrentATR, double percent_Doji_Body, double ATR_doji_multi)
{
   //Set symbol string and indicator buffers
   string    CurrentSymbol    = Symbol();

   //Find required Macd signal lines and normalize to 10 places to prevent rounding errors in crossovers
   double    CurrentHigh = NormalizeDouble(iHigh(Symbol(),Period(),1), 10);
   double    CurrentLow = NormalizeDouble(iLow(Symbol(),Period(),1), 10);
   double    CurrentOpen = NormalizeDouble(iOpen(Symbol(),Period(),1), 10);
   double    CurrentClose = NormalizeDouble(iClose(Symbol(),Period(),1), 10);
   
   // Calculate wicks
   double WickLength = CurrentHigh - CurrentLow;
   double BodyLength = MathAbs(CurrentClose - CurrentOpen);
 
   //Doji Formation                                
   if(WickLength >= ATR_doji_multi*CurrentATR && (BodyLength/WickLength)<(percent_Doji_Body/100))
      return   "Doji";
   else
      return   "No Trade";
}

//Custom function that returns long and short signals based off EMA and Close price.
string GetEmaOpenSignal()
{
   //Set symbol string and indicator buffers
   string    CurrentSymbol    = Symbol();
   const int StartCandle      = 0;
   const int RequiredCandles  = 2; //How many candles are required to be stored in Expert 
   
   //Indicator Variables and Buffers
   const int IndexEma         = 0; //EMA Line
   double    BufferEma[];         //[current confirmed,not confirmed]    

   //Define EMA, from not confirmed candle 0, for 2 candles, and store results 
   bool      FillEma   = CopyBuffer(HandleEma,IndexEma,  StartCandle,RequiredCandles,BufferEma);
   if(FillEma==false) 
      return "Buffer Not Full Ema"; //If buffers are not completely filled, return to end onTick

   //Gets the current confirmed EMA value
   double CurrentEma   = NormalizeDouble(BufferEma[0],10);
   double CurrentClose = NormalizeDouble(iClose(Symbol(),Period(),1), 10);

   //Submit Ema Long and Short Trades
   if(CurrentClose > CurrentEma)
      return("Long");
   else if (CurrentClose < CurrentEma)
      return("Short");
   else
      return("No Trade");
}

string GetRsiOpenSignal(double Rsioverbought, double Rsioversold)
{
   //Set symbol string and indicator buffers
   string    CurrentSymbol    = Symbol();
   const int StartCandle      = 0;
   const int RequiredCandles  = 3; //How many candles are required to be stored in Expert 
   
   //Indicator Variables and Buffers
   const int IndexRsi         = 0; //RSI Line
   double    BufferRsi[];         //[current confirmed,not confirmed]    

   //Define EMA, from not confirmed candle 0, for 2 candles, and store results 
   bool      FillRsi   = CopyBuffer(HandleRsi,IndexRsi,StartCandle,RequiredCandles,BufferRsi);
   if(FillRsi==false) 
      return "Buffer Not Full Rsi"; //If buffers are not completely filled, return to end onTick

   //Gets the current confirmed EMA value
   double PriorRsi      = NormalizeDouble(BufferRsi[0],10);
   double CurrentRsi    = NormalizeDouble(BufferRsi[1],10);

   //Submit Ema Long and Short Trades
   if (PriorRsi <= Rsioverbought && CurrentRsi > Rsioverbought)
      return("Long Exit");
   else if (PriorRsi >= Rsioversold && CurrentRsi < Rsioversold)
      return ("Short Exit");   
   else if(CurrentRsi > Rsioverbought)
      return("Short");
   else if (CurrentRsi < Rsioversold)
      return("Long");
   else
      return("No Trade");
}


//Processes open trades for buy and sell
ulong ProcessTradeOpen(ENUM_ORDER_TYPE OrderType, double CurrentAtr,int TP, long magic)
{
   //Set symbol string and variables
   string CurrentSymbol   = Symbol();  
   double Price           = 0;
   double StopLossPrice   = 0;
   double TakeProfitPrice = 0;

   //Get price, stop loss, take profit for open and close orders
   if(OrderType == ORDER_TYPE_BUY)
   {
      Price           = NormalizeDouble(SymbolInfoDouble(CurrentSymbol, SYMBOL_ASK), Digits());
      StopLossPrice   = NormalizeDouble(Price - CurrentAtr*AtrLossMulti, Digits());
      TakeProfitPrice = NormalizeDouble(Price + CurrentAtr*AtrProfitMulti, Digits());
   }
   else if(OrderType == ORDER_TYPE_SELL)
   {
      Price           = NormalizeDouble(SymbolInfoDouble(CurrentSymbol, SYMBOL_BID), Digits());
      StopLossPrice   = NormalizeDouble(Price + CurrentAtr*AtrLossMulti, Digits());
      TakeProfitPrice = NormalizeDouble(Price - CurrentAtr*AtrProfitMulti, Digits());  
   }
   
   //Get lot size
   double LotSize = OptimalLotSize(CurrentSymbol,Price,StopLossPrice);
   
   //Exit any trades that are currently open. Enter new trade.
   Trade.SetExpertMagicNumber(magic);
   if(TP == 1){  // Static Stop Loss
      Trade.PositionOpen(CurrentSymbol,OrderType,LotSize,Price,StopLossPrice,TakeProfitPrice,InpTradeComment);
   }
   else if(TP == 0){  // Trailing Stop Loss
      Trade.PositionOpen(CurrentSymbol,OrderType,LotSize,Price,StopLossPrice,0 ,InpTradeComment);
   }

   //Get Position Ticket Number
   ulong  Ticket = PositionGetTicket(PositionsTotal() - 1);

   //Add in any error handling
   Print("Trade Processed For ", CurrentSymbol," OrderType ",OrderType, " Lot Size ", LotSize, " Ticket ", Ticket);

   // Return ticket number
   return(Ticket);
}


void ProcessTradeClose() {
   //Set symbol string and variables
   string CurrentSymbol   = Symbol();
   Trade.PositionClose(CurrentSymbol);
}


//Finds the optimal lot size for the trade 
//https://www.youtube.com/watch?v=Zft8X3htrcc&t=724s
double OptimalLotSize(string CurrentSymbol, double EntryPrice, double StopLoss)
{
   //Set symbol string and calculate point value
   double TickSize      = SymbolInfoDouble(CurrentSymbol,SYMBOL_TRADE_TICK_SIZE);
   double TickValue     = SymbolInfoDouble(CurrentSymbol,SYMBOL_TRADE_TICK_VALUE);
   if(SymbolInfoInteger(CurrentSymbol,SYMBOL_DIGITS) <= 3)  // Handle JPY pairs
        TickValue = TickValue/100;
   double PointAmount   = SymbolInfoDouble(CurrentSymbol,SYMBOL_POINT);
   double TicksPerPoint = TickSize/PointAmount;
   double PointValue    = TickValue/TicksPerPoint;

   //Calculate risk based off entry and stop loss level by pips
   double RiskPoints = MathAbs((EntryPrice - StopLoss)/TickSize);
      
   //Set risk model - Fixed or compounding
   if(RiskCompounding == true)
      CurrentEquityRisk = AccountInfoDouble(ACCOUNT_EQUITY);
   else
      CurrentEquityRisk = StartingEquity; 

   //Calculate total risk amount in dollars
   double RiskAmount = CurrentEquityRisk * MaxLossPrc;

   //Calculate lot size
   double RiskLots   = NormalizeDouble(0.5*RiskAmount/(RiskPoints*PointValue),2);

   //Print values in Journal to check if operating correctly
   PrintFormat("TickSize=%f,TickValue=%f,PointAmount=%f,TicksPerPoint=%f,PointValue=%f,",
                  TickSize,TickValue,PointAmount,TicksPerPoint,PointValue);   
   PrintFormat("EntryPrice=%f,StopLoss=%f,RiskPoints=%f,RiskAmount=%f,RiskLots=%f,",
                  EntryPrice,StopLoss,RiskPoints,RiskAmount,RiskLots);   

   //Return optimal lot size
   return RiskLots;
}

// Check if there is an existing long trade
bool IsLongTradeOpen() {
    for (int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if (ticket > 0 && PositionGetInteger(POSITION_TYPE, ticket) == POSITION_TYPE_BUY) {
            return true; // Long trade is already open
        }
    }
    return false; // No long trades found
}

bool IsShortTradeOpen() {
    for (int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        if (ticket > 0 && PositionGetInteger(POSITION_TYPE, ticket) == POSITION_TYPE_SELL) {
            return true; // Long trade is already open
        }
    }    
    return false; // No long trades found
}

int CheckTrades() {  
    int totalTrades = 0;
    string symb = "";
    for (int i = 0; i < PositionsTotal(); i++) {
        ulong ticket = PositionGetTicket(i);
        symb = PositionGetSymbol(i);
        if (ticket > 0 && symb == Symbol()) {
            totalTrades++;
        }
    }
    return totalTrades;
}

//Adjust Trailing Stop Loss based off ATR
void AdjustTsl(ulong Ticket, double CurrentAtr, double AtrMulti, long magic, int checktrade)
{
   //Set symbol string and variables
   string CurrentSymbol   = Symbol();
   double Price           = 0.0;
   double OptimalStopLoss = 0.0;  
   Trade.SetExpertMagicNumber(magic);
   //Check correct ticket number is selected for further position data to be stored. Return if error.
   if (!PositionSelectByTicket(Ticket))
      return;
   if (checktrade == 1) {
      //Store position data variables
      ulong  PositionDirection = PositionGetInteger(POSITION_TYPE);
      double CurrentStopLoss   = PositionGetDouble(POSITION_SL);
      double CurrentTakeProfit = PositionGetDouble(POSITION_TP);
      double priceOpen         = PositionGetDouble(POSITION_PRICE_OPEN);
     
      
      //Check if position direction is long 
      if (PositionDirection==POSITION_TYPE_BUY)
      {
         //Get optimal stop loss value
         Price           = NormalizeDouble(SymbolInfoDouble(CurrentSymbol, SYMBOL_ASK), Digits());
         OptimalStopLoss = NormalizeDouble(Price - CurrentAtr*AtrMulti, Digits());
         
         //Check if optimal stop loss is greater than current stop loss. If TRUE, adjust stop loss
         if (priceOpen > CurrentStopLoss) {
            Trade.PositionModify(Ticket,priceOpen,CurrentTakeProfit);
         }else if(OptimalStopLoss > CurrentStopLoss) {
            Trade.PositionModify(Ticket,OptimalStopLoss,CurrentTakeProfit);
            Print("Ticket ", Ticket, " for symbol ", CurrentSymbol," stop loss adjusted to ", OptimalStopLoss);
         }
   
         //Return once complete
         return;
      } 
      
      //Check if position direction is short 
      if (PositionDirection==POSITION_TYPE_SELL)
      {
         //Get optimal stop loss value
         Price           = NormalizeDouble(SymbolInfoDouble(CurrentSymbol, SYMBOL_BID), Digits());
         OptimalStopLoss = NormalizeDouble(Price + CurrentAtr*AtrMulti, Digits());
   
         //Check if optimal stop loss is less than current stop loss. If TRUE, adjust stop loss
         if (priceOpen < CurrentStopLoss) {
            Trade.PositionModify(Ticket,priceOpen,CurrentTakeProfit);
         }else if(OptimalStopLoss < CurrentStopLoss) {
            Trade.PositionModify(Ticket,OptimalStopLoss,CurrentTakeProfit);
            Print("Ticket ", Ticket, " for symbol ", CurrentSymbol," stop loss adjusted to ", OptimalStopLoss);
         }
         //Return once complete
         return;
      } 
    }
}