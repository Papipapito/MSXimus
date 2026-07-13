// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vopl3.h for the primary calling header

#include "Vopl3__pch.h"
#include "Vopl3__Syms.h"
#include "Vopl3___024root.h"

#ifdef VL_DEBUG
VL_ATTR_COLD void Vopl3___024root___dump_triggers__stl(Vopl3___024root* vlSelf);
#endif  // VL_DEBUG

VL_ATTR_COLD void Vopl3___024root___eval_triggers__stl(Vopl3___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vopl3__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vopl3___024root___eval_triggers__stl\n"); );
    // Body
    vlSelf->__VstlTriggered.set(0U, (IData)(vlSelf->__VstlFirstIteration));
    vlSelf->__VstlTriggered.set(1U, ((IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob) 
                                     != (IData)(vlSelf->__Vtrigprevexpr___TOP__opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob__0)));
    vlSelf->__Vtrigprevexpr___TOP__opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob__0 
        = vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob;
    if (VL_UNLIKELY((1U & (~ (IData)(vlSelf->__VstlDidInit))))) {
        vlSelf->__VstlDidInit = 1U;
        vlSelf->__VstlTriggered.set(1U, 1U);
    }
#ifdef VL_DEBUG
    if (VL_UNLIKELY(vlSymsp->_vm_contextp__->debug())) {
        Vopl3___024root___dump_triggers__stl(vlSelf);
    }
#endif
}
