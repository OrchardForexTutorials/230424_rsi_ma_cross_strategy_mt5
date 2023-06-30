/*

   RSI MA Cross Custom
   Copyright 2023, Novateq Pty Ltd
   https://orchardforex.com

*/

/*

   Rules:
   Buy when RSI Oversold (<15) and EMA(5) crosses above EMA(10)
   Sell when RSI Overbought (>80) and EMA(5) crosses below EMA(10)

   **added
   Buy Stop loss at nearest swing low(5 fractal)
   Buy TakeProfit at 1:1
   Sell Stop loss at nearest swing high(5 fractal)
   Sell TakeProfit at 1:1

*/

#define app_name  "RSI MA Cross Custom"
#define app_magic 232323

#property copyright "Copyright 2013-2023 Novateq Pty Ltd"
#property link "https://orchardforex.com"
#property version "1.0"
#property description "RSI OB/OS combine with MA cross"

//
//	Inputs
//

//
//	Fast MA
//
input int                InpFastMAPeriod       = 5;           // Fast MA Bars
input ENUM_MA_METHOD     InpFastMAMethod       = MODE_EMA;    // Fast MA Method
input ENUM_APPLIED_PRICE InpFastMAAppliedPrice = PRICE_CLOSE; // Fast MA Applied Price

//
//	Slow MA
//
input int                InpSlowMAPeriod       = 10;          // Slow MA Bars
input ENUM_MA_METHOD     InpSlowMAMethod       = MODE_EMA;    // Slow MA Method
input ENUM_APPLIED_PRICE InpSlowMAAppliedPrice = PRICE_CLOSE; // Slow MA Applied Price

//
//	RSI
//
input int                InpRSIPeriod          = 10;          // RSI Period
input ENUM_APPLIED_PRICE InpRSIAppliedPrice    = PRICE_CLOSE; //	RSI Applied Price
input double             InpRSIOverboughtLevel = 80;          // RSI Overbought
input double             InpRSIOversoldLevel   = 15;          // RSI Oversold

// sl/tp
input int                InpSwingPeriod        = 5;   // Swing high/low period
input double             InpTakeProfitRatio    = 1.0; // tp:sl ratio

//
//	Basic inputs
//
input double             InpOrderSize          = 0.01;      // Order size in lots
input int                InpMagic              = app_magic; // Magic number
input string             InpTradeComment       = app_name;  // Trade comment

// Bring in the trade class to make trading easier
#include <Trade/Trade.mqh>
CTrade        Trade;
CPositionInfo PositionInfo;

// Handles and buffers for the moving averages
int           HandleFastMA;
int           HandleSlowMA;
int           HandleRSI;

double        BufferFastMA[];
double        BufferSlowMA[];
double        BufferRSI[];
const int     BufferValuesRequired = 3;

;
//
//	Initialisation
//
int OnInit() {

   // Reset the new bar
   IsNewBar();

   // MT5 Specific
   Trade.SetExpertMagicNumber( InpMagic );

   HandleFastMA = iMA( Symbol(), Period(), InpFastMAPeriod, 0, InpFastMAMethod, InpFastMAAppliedPrice );
   HandleSlowMA = iMA( Symbol(), Period(), InpSlowMAPeriod, 0, InpSlowMAMethod, InpSlowMAAppliedPrice );
   HandleRSI    = iRSI( Symbol(), Period(), InpRSIPeriod, InpRSIAppliedPrice );
   ArraySetAsSeries( BufferFastMA, true );
   ArraySetAsSeries( BufferSlowMA, true );
   ArraySetAsSeries( BufferRSI, true );

   if ( HandleFastMA == INVALID_HANDLE || HandleSlowMA == INVALID_HANDLE || HandleRSI == INVALID_HANDLE ) {
      Print( "Error creating handles to indicators" );
      return INIT_FAILED;
   }

   // end MT5 Specific

   return ( INIT_SUCCEEDED );
}

void OnDeinit( const int reason ) {

   // MT5 Specific
   IndicatorRelease( HandleFastMA );
   IndicatorRelease( HandleSlowMA );
   IndicatorRelease( HandleRSI );
   // end MT5 Specific
}

void OnTick() {

   // Enter a trade on a cross of fast MA over slow MA
   // Exit any existing opposite at the same time
   // means there can only be one trade open at a time
   // Not a great trading strategy but a good demo

   bool newBar            = IsNewBar();
   bool conditionOpenBuy  = false;
   bool conditionOpenSell = false;

   if ( !newBar ) return;

   // Get the fast and slow ma values for bar 1 and bar 2
   if ( !FillBuffers( BufferValuesRequired ) ) return;

   // Compare, if Fast 1 is above Slow 1 and Fast 2 is not above Slow 2 then
   // there is a cross up

   conditionOpenBuy     = ( CrossUp( BufferFastMA, BufferSlowMA, 1 ) && ( BufferRSI[1] < InpRSIOversoldLevel ) );
   conditionOpenSell    = ( CrossDown( BufferFastMA, BufferSlowMA, 1 ) && ( BufferRSI[1] > InpRSIOverboughtLevel ) );

   double stopLossPrice = 0;

   if ( conditionOpenBuy ) {
      SwingLow( 0, InpSwingPeriod, stopLossPrice );
      TradeOpenSLPriceTPRatio( ORDER_TYPE_BUY, InpOrderSize, InpTradeComment, stopLossPrice, InpTakeProfitRatio );
      return;
   }
   if ( conditionOpenSell ) {
      SwingHigh( 0, InpSwingPeriod, stopLossPrice );
      TradeOpenSLPriceTPRatio( ORDER_TYPE_SELL, InpOrderSize, InpTradeComment, stopLossPrice, InpTakeProfitRatio );
   }

   //
}

double PipsToDouble( int pips ) { return PointsToDouble( PipsToPoints( pips ) ); }

int    PipsToPoints( int pips ) { return pips * ( ( Digits() == 3 || Digits() == 5 ) ? 10 : 1 ); }

double PointsToDouble( int points ) {

   return points * Point(); // just number of points * size of a point
}

bool IsNewBar() {

   static datetime previous_time = 0;
   datetime        current_time  = iTime( Symbol(), Period(), 0 );
   if ( previous_time != current_time ) {
      previous_time = current_time;
      return true;
   }
   return false;
}

bool CrossUp( double &arr1[], double &arr2[], int index1, int index2 = -1 ) {

   if ( index2 < 0 ) index2 = index1 + 1;
   bool cross = ( arr1[index1] > arr2[index1] ) && !( arr1[index2] > arr2[index2] );
   return cross;
}

bool CrossDown( double &arr1[], double &arr2[], int index1, int index2 = -1 ) {

   if ( index2 < 0 ) index2 = index1 + 1;
   bool cross = ( arr1[index1] < arr2[index1] ) && !( arr1[index2] < arr2[index2] );
   return cross;
}

int SwingHigh( int start, int lookback, double &value ) {

   int highBar = start;
   do {
      start   = highBar;
      highBar = iHighest( Symbol(), Period(), MODE_HIGH, lookback, start );
   } while ( highBar != start );
   value = iHigh( Symbol(), Period(), highBar );
   return highBar;
}

int SwingLow( int start, int lookback, double &value ) {

   int lowBar = start;
   do {
      start  = lowBar;
      lowBar = iLowest( Symbol(), Period(), MODE_LOW, lookback, start );
   } while ( lowBar != start );
   value = iLow( Symbol(), Period(), lowBar );
   return ( lowBar );
}

// MT5 Specific

// Load values from the indicators into buffers
bool FillBuffers( int valuesRequired ) {

   if ( CopyBuffer( HandleFastMA, 0, 0, valuesRequired, BufferFastMA ) < valuesRequired ) {
      Print( "Insufficient results from fast MA" );
      return false;
   }
   if ( CopyBuffer( HandleSlowMA, 0, 0, valuesRequired, BufferSlowMA ) < valuesRequired ) {
      Print( "Insufficient results from slow MA" );
      return false;
   }
   if ( CopyBuffer( HandleRSI, 0, 0, valuesRequired, BufferRSI ) < valuesRequired ) {
      Print( "Insufficient results from RSI" );
      return false;
   }

   return true;
}

// Open a market price trade given a stop loss price and take profit ratio
void TradeOpenSLPriceTPRatio( ENUM_ORDER_TYPE type, double volume, string tradeComment, double stopLossPrice = 0, double takeProfitRatio = 0 ) {

   if ( stopLossPrice < 0 ) return;

   double price;
   double closePrice;
   double sl         = stopLossPrice;
   double tp         = 0;
   double stopsLevel = PointsToDouble( ( int )SymbolInfoInteger( Symbol(), SYMBOL_TRADE_STOPS_LEVEL ) );

   if ( type == ORDER_TYPE_BUY ) {
      price      = SymbolInfoDouble( Symbol(), SYMBOL_ASK );
      closePrice = SymbolInfoDouble( Symbol(), SYMBOL_BID );
      if ( stopLossPrice > 0 && stopLossPrice > ( closePrice - stopsLevel ) ) return;
   }
   else {
      price      = SymbolInfoDouble( Symbol(), SYMBOL_BID );
      closePrice = SymbolInfoDouble( Symbol(), SYMBOL_ASK );
      if ( stopLossPrice > 0 && stopLossPrice < ( closePrice + stopsLevel ) ) return;
   }
   if ( takeProfitRatio > 0 ) tp = price + ( ( price - stopLossPrice ) * takeProfitRatio );

   price = NormalizeDouble( price, Digits() );
   sl    = NormalizeDouble( sl, Digits() );
   tp    = NormalizeDouble( tp, Digits() );

   if ( !Trade.PositionOpen( Symbol(), type, volume, price, sl, tp, tradeComment ) ) {
      Print( "Open failed for %s, %s, price=%f, sl=%f, tp=%f", Symbol(), EnumToString( type ), price, sl, tp );
   }
}

// end MT5 Specific

// That's all folks
