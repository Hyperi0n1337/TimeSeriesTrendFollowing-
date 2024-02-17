//+------------------------------------------------------------------+
//|                                                           SR.mqh |
//|                        Copyright 2020, MetaQuotes Software Corp. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2020, MetaQuotes Software Corp."
#property link      "https://www.mql5.com"

#include <Arrays/ArrayObj.mqh>
#include <Object.mqh>

#define OVERLAP_COLOR clrYellow

//supposed to be a struct but mql doesnt allow struct inheriting class
class SRContext : public CObject {
public:                             
   ENUM_TIMEFRAMES timeframe;
   
   int indicator8;
   int indicator_builtin;
   color draw_color;

   SRContext(ENUM_TIMEFRAMES timeframe, color draw_color);
   ~SRContext();
   
   int Compare(const CObject* next, const int mode = 0) const override;
};

SRContext::SRContext(ENUM_TIMEFRAMES t, color c):
   timeframe(t),
   indicator8(-1),
   indicator_builtin(-1),
   draw_color(c)
{
   indicator8 = iCustom(_Symbol, t, "Market\\Lighthouse MT5", 0, true, 5.0, 0, false, false); 
   indicator_builtin = iCustom(_Symbol, t, "Market\\Lighthouse MT5", 0, true, 5.0, 1, false, false);   
}


SRContext::~SRContext() {
   IndicatorRelease(indicator8);
   IndicatorRelease(indicator_builtin);
}

int 
SRContext::Compare(const CObject* next, const int mode = 0) const override { 
   return (int) timeframe - (int) ( ( (SRContext*) next ).timeframe);
}

class SRLine: public CObject {
public:
   double   price;
   color    draw_color;
   
   SRLine(double p, color c):
      price(p),
      draw_color(c)
   {} 
   
   int Compare(const CObject* next, const int mode = 0) const override;
};

int 
SRLine::Compare(const CObject* next, const int mode = 0) const override { 
   return (int) (price * 100000) - (int) ( ( (SRLine*) next ).price * 100000 );
}

/*
   Support and Resistance manager
*/

class SR {
private:
   
   CArrayObj sr_context_list;    //sorted
   CArrayObj sr_line_list;       //sorted
   int   sr_line_obj_count;
   
   int SRLineSearch(const double price) const;
public:

   SR(): sr_line_obj_count(0) {
      sr_context_list.Sort(0);
      sr_line_list.Sort(0);
   }
   ~SR() {}
   
   void AddTimeframe(const ENUM_TIMEFRAMES new_timeframe, const color draw_color);
   void RemoveTimeframe(const ENUM_TIMEFRAMES timeframe);
   bool TimeframeExist(const ENUM_TIMEFRAMES timrframe) const;
   
   double GetNextSupport(const double curr_price) const;
   double GetNextResistence(const double curr_price) const;
   
   void Update();
   void DrawSR();
};

int 
SR::SRLineSearch(const double price) const {
   SRLine* line = new SRLine(price, 0);

   int idx = sr_line_list.Search(line);
   
   delete line;
   return idx;
}

void
SR::AddTimeframe(const ENUM_TIMEFRAMES new_timeframe, const color draw_color) {
   SRContext *context = new SRContext(new_timeframe, draw_color);
   if(sr_context_list.Search(context) < 0) {
      sr_context_list.InsertSort(context);  
   }
}

void 
SR::RemoveTimeframe(const ENUM_TIMEFRAMES timeframe) {
   for(int i = 0; i < sr_context_list.Total(); ++i) {
      if(( (SRContext*) sr_context_list.At(i) ).timeframe == timeframe) {
         sr_context_list.Delete(i);
      }
   }
   
   //rebuild sr_lines
   Update();
}

bool 
SR::TimeframeExist(const ENUM_TIMEFRAMES timeframe) const {
   for(int i = 0; i < sr_context_list.Total(); ++i) {
      if(( (SRContext*) sr_context_list.At(i) ).timeframe == timeframe) {
         return true;
      }
   }
   return false;
}
   
double 
SR::GetNextSupport(const double curr_price) const {
   SRLine* sr_line_ptr = NULL;
   
   if(sr_line_list.Total() == 0) {
      return 0.0;
   }
   
   sr_line_ptr = (SRLine*) sr_line_list.At(0);
   if(curr_price < sr_line_ptr.price ) {
      return 0.0;
   }
   
   double ret = sr_line_ptr.price;
   for(int i = 1; i < sr_line_list.Total(); ++i) {
      sr_line_ptr = (SRLine*) sr_line_list.At(i);
      if(sr_line_ptr.price >= curr_price) {
         break;
      }
      ret = sr_line_ptr.price;
   }
   
   return ret;
}

double 
SR::GetNextResistence(const double curr_price) const {
   SRLine* sr_line_ptr = NULL;
   
   if(sr_line_list.Total() == 0) {
      return 0.0;
   }
   
   sr_line_ptr = (SRLine*) ( sr_line_list.At( sr_line_list.Total() - 1 ) );
   if(curr_price > sr_line_ptr.price ) {
      return 0.0;
   }
   
   double ret = sr_line_ptr.price;
   for(int i = sr_line_list.Total() - 2; i >= 0; --i) {
   
      sr_line_ptr = (SRLine*) sr_line_list.At(i);
      if(sr_line_ptr.price <= curr_price) {
         break;
      }
      ret = sr_line_ptr.price;
   }
   
   return ret;
}
   
void 
SR::Update() {
   
   sr_line_list.Clear();
   
   if(sr_context_list.Total() == 0) {
      return;
   }
   
   double sr_buff[1];
   SRContext* context = NULL;
   
   //potentially no second context so just get sr of the first context first
   context = (SRContext*) sr_context_list.At(0);
   for(int i = 0; i < 8; ++i) {
      CopyBuffer(context.indicator8, i, 0, 1, sr_buff);
      sr_line_list.InsertSort(new SRLine(sr_buff[0], context.draw_color));
   }
   
   //for any additional context
   
   int idx_buff = -1;
   //int ret;
   for(int i = 1; i < sr_context_list.Total(); ++i) {
   
      context = (SRContext*) sr_context_list.At(i);
      for(int j = 0; j < 8; ++j) {
         CopyBuffer(context.indicator8, j, 0, 1, sr_buff);

         idx_buff = SRLineSearch(sr_buff[0]);
         if(idx_buff < 0) {
            sr_line_list.InsertSort(new SRLine(sr_buff[0], context.draw_color));
         } else {
            ( (SRLine*) sr_line_list.At(idx_buff)).draw_color = OVERLAP_COLOR;
         }
      }
   }
  
   /*
   SRLine* line;
   Print("------------------------------");
   for(int i = 0; i < sr_line_list.Total(); ++i) {
      line = (SRLine*) sr_line_list.At(i);
      Print("price: ", line.price, " color:", line.draw_color);
   }*/
   
}

void
SR::DrawSR() {
   string obj_name;
   SRLine* line;
   
   //delete extra objects
   while(sr_line_obj_count > sr_line_list.Total()) {
      obj_name = StringFormat("sr_line%d", sr_line_obj_count - 1);
      ObjectDelete(0, obj_name);
      sr_line_obj_count--;
   }

   //move existing sr line objects
   
   for(int i = 0 ; i < sr_line_obj_count; ++i) {
      line = (SRLine*) sr_line_list.At(i);
      obj_name = StringFormat("sr_line%d", i);
      if(ObjectGetInteger(0, obj_name, OBJPROP_COLOR) != line.draw_color) {
         ObjectSetInteger(0, obj_name, OBJPROP_COLOR, line.draw_color);
      }
      ObjectMove(0, obj_name, 0, 0, line.price);
   }
   
   //create new sr line objects
   while(sr_line_obj_count < sr_line_list.Total()) {
      obj_name = StringFormat("sr_line%d", sr_line_obj_count);
      line = (SRLine*) sr_line_list.At(sr_line_obj_count);
      ObjectCreate(0, obj_name, OBJ_HLINE, 0, 0, line.price);
      ObjectSetInteger(0, obj_name, OBJPROP_COLOR, line.draw_color);
      sr_line_obj_count++;
   }
}