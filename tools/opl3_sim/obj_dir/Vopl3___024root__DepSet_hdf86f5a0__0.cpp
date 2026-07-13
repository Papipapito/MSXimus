// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vopl3.h for the primary calling header

#include "Vopl3__pch.h"
#include "Vopl3__Syms.h"
#include "Vopl3___024root.h"

#ifdef VL_DEBUG
VL_ATTR_COLD void Vopl3___024root___dump_triggers__act(Vopl3___024root* vlSelf);
#endif  // VL_DEBUG

void Vopl3___024root___eval_triggers__act(Vopl3___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vopl3__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vopl3___024root___eval_triggers__act\n"); );
    // Body
    vlSelf->__VactTriggered.set(0U, ((IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob) 
                                     != (IData)(vlSelf->__Vtrigprevexpr___TOP__opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob__1)));
    vlSelf->__VactTriggered.set(1U, (((IData)(vlSelf->clk) 
                                      & (~ (IData)(vlSelf->__Vtrigprevexpr___TOP__clk__0))) 
                                     | ((~ (IData)(vlSelf->ic_n)) 
                                        & (IData)(vlSelf->__Vtrigprevexpr___TOP__ic_n__0))));
    vlSelf->__VactTriggered.set(2U, ((IData)(vlSelf->clk_host) 
                                     & (~ (IData)(vlSelf->__Vtrigprevexpr___TOP__clk_host__0))));
    vlSelf->__VactTriggered.set(3U, ((IData)(vlSelf->clk) 
                                     & (~ (IData)(vlSelf->__Vtrigprevexpr___TOP__clk__0))));
    vlSelf->__VactTriggered.set(4U, (((IData)(vlSelf->clk_host) 
                                      & (~ (IData)(vlSelf->__Vtrigprevexpr___TOP__clk_host__0))) 
                                     | ((~ (IData)(vlSelf->ic_n)) 
                                        & (IData)(vlSelf->__Vtrigprevexpr___TOP__ic_n__0))));
    vlSelf->__VactTriggered.set(5U, (((IData)(vlSelf->clk) 
                                      & (~ (IData)(vlSelf->__Vtrigprevexpr___TOP__clk__0))) 
                                     | ((~ (IData)(vlSelf->opl3__DOT__host_if__DOT____Vcellinp__afifo__i_rd_reset_n)) 
                                        & (IData)(vlSelf->__Vtrigprevexpr___TOP__opl3__DOT__host_if__DOT____Vcellinp__afifo__i_rd_reset_n__0))));
    vlSelf->__Vtrigprevexpr___TOP__opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob__1 
        = vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob;
    vlSelf->__Vtrigprevexpr___TOP__clk__0 = vlSelf->clk;
    vlSelf->__Vtrigprevexpr___TOP__ic_n__0 = vlSelf->ic_n;
    vlSelf->__Vtrigprevexpr___TOP__clk_host__0 = vlSelf->clk_host;
    vlSelf->__Vtrigprevexpr___TOP__opl3__DOT__host_if__DOT____Vcellinp__afifo__i_rd_reset_n__0 
        = vlSelf->opl3__DOT__host_if__DOT____Vcellinp__afifo__i_rd_reset_n;
    if (VL_UNLIKELY((1U & (~ (IData)(vlSelf->__VactDidInit))))) {
        vlSelf->__VactDidInit = 1U;
        vlSelf->__VactTriggered.set(0U, 1U);
    }
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vopl3___024root___dump_triggers__act(vlSelf);
    }
#endif
}
