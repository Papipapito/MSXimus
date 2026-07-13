// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vopl3.h for the primary calling header

#include "Vopl3__pch.h"
#include "Vopl3___024root.h"

VL_INLINE_OPT void Vopl3___024root___act_sequent__TOP__0(Vopl3___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vopl3__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vopl3___024root___act_sequent__TOP__0\n"); );
    // Body
    vlSelf->opl3__DOT__channels__DOT__next_self[0U] 
        = vlSelf->opl3__DOT__channels__DOT__self[0U];
    vlSelf->opl3__DOT__channels__DOT__next_self[1U] 
        = vlSelf->opl3__DOT__channels__DOT__self[1U];
    vlSelf->opl3__DOT__channels__DOT__next_self[2U] 
        = vlSelf->opl3__DOT__channels__DOT__self[2U];
    vlSelf->opl3__DOT__channels__DOT__signals = 0U;
    if (((((((((0U == vlSelf->opl3__DOT__channels__DOT__state) 
               | (1U == vlSelf->opl3__DOT__channels__DOT__state)) 
              | (2U == vlSelf->opl3__DOT__channels__DOT__state)) 
             | (3U == vlSelf->opl3__DOT__channels__DOT__state)) 
            | (4U == vlSelf->opl3__DOT__channels__DOT__state)) 
           | (5U == vlSelf->opl3__DOT__channels__DOT__state)) 
          | (6U == vlSelf->opl3__DOT__channels__DOT__state)) 
         | (7U == vlSelf->opl3__DOT__channels__DOT__state))) {
        if ((0U != vlSelf->opl3__DOT__channels__DOT__state)) {
            if ((1U == vlSelf->opl3__DOT__channels__DOT__state)) {
                vlSelf->opl3__DOT__channels__DOT__signals 
                    = ((0xffffffU & vlSelf->opl3__DOT__channels__DOT__signals) 
                       | (0x1000000U | (0x3e000000U 
                                        & (((IData)(3U) 
                                            + ((vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                << 0x14U) 
                                               | (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                  >> 0xcU))) 
                                           << 0x19U))));
            } else if ((2U == vlSelf->opl3__DOT__channels__DOT__state)) {
                vlSelf->opl3__DOT__channels__DOT__next_self[1U] 
                    = ((0x8003ffffU & vlSelf->opl3__DOT__channels__DOT__next_self[1U]) 
                       | ((IData)(vlSelf->opl3__DOT__channels__DOT__operator_mem_out) 
                          << 0x12U));
                vlSelf->opl3__DOT__channels__DOT__signals 
                    = ((0xffffffU & vlSelf->opl3__DOT__channels__DOT__signals) 
                       | (0x1000000U | (0x3e000000U 
                                        & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                           << 0xdU))));
            } else if ((3U == vlSelf->opl3__DOT__channels__DOT__state)) {
                vlSelf->opl3__DOT__channels__DOT__signals 
                    = ((0x3f0fffffU & vlSelf->opl3__DOT__channels__DOT__signals) 
                       | (0xf00000U & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                       << 0xcU)));
                vlSelf->opl3__DOT__channels__DOT__signals 
                    = ((0x3ff0001fU & vlSelf->opl3__DOT__channels__DOT__signals) 
                       | (0xfffe0U & (((1U & (IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob))
                                        ? (VL_EXTENDS_II(15,13, (IData)(vlSelf->opl3__DOT__channels__DOT__operator_mem_out)) 
                                           + VL_EXTENDS_II(15,13, 
                                                           (0x1fffU 
                                                            & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                               >> 0x12U))))
                                        : VL_EXTENDS_II(15,13, 
                                                        (0x1fffU 
                                                         & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                            >> 0x12U)))) 
                                      << 5U)));
                if (((IData)(vlSelf->opl3__DOT__channels__DOT__ryt) 
                     & (~ (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                           >> 0x11U)))) {
                    if ((6U == (0xfU & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                        >> 8U)))) {
                        vlSelf->opl3__DOT__channels__DOT__signals 
                            = ((0x3ff0001fU & vlSelf->opl3__DOT__channels__DOT__signals) 
                               | (0xfffe0U & (VL_MULS_III(32, (IData)(2U), 
                                                          VL_EXTENDS_II(32,13, 
                                                                        (0x1fffU 
                                                                         & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                                            >> 0x12U)))) 
                                              << 5U)));
                    } else if (((7U == (0xfU & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                >> 8U))) 
                                || (8U == (0xfU & (
                                                   vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                   >> 8U))))) {
                        vlSelf->opl3__DOT__channels__DOT__signals 
                            = ((0x3ff0001fU & vlSelf->opl3__DOT__channels__DOT__signals) 
                               | (0xfffe0U & (VL_MULS_III(32, (IData)(2U), 
                                                          (VL_EXTENDS_II(32,13, (IData)(vlSelf->opl3__DOT__channels__DOT__operator_mem_out)) 
                                                           + 
                                                           VL_EXTENDS_II(32,13, 
                                                                         (0x1fffU 
                                                                          & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                                             >> 0x12U))))) 
                                              << 5U)));
                    }
                }
                if ((3U > (0xfU & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                   >> 8U)))) {
                    if ((0x20000U & vlSelf->opl3__DOT__channels__DOT__self[1U])) {
                        vlSelf->opl3__DOT__channels__DOT__signals 
                            = ((0x3ffffff7U & vlSelf->opl3__DOT__channels__DOT__signals) 
                               | (8U & (((IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob) 
                                         >> 1U) & (
                                                   (~ 
                                                    ((5U 
                                                      >= 
                                                      (7U 
                                                       & ((IData)(3U) 
                                                          + 
                                                          (0xfU 
                                                           & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                              >> 8U))))) 
                                                     && (1U 
                                                         & ((IData)(vlSelf->opl3__DOT__channels__DOT__connection_sel) 
                                                            >> 
                                                            (7U 
                                                             & ((IData)(3U) 
                                                                + 
                                                                (0xfU 
                                                                 & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                                    >> 8U)))))))) 
                                                   << 3U))));
                        vlSelf->opl3__DOT__channels__DOT__signals 
                            = ((0x3ffffffbU & vlSelf->opl3__DOT__channels__DOT__signals) 
                               | (4U & (((IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob) 
                                         >> 3U) & (
                                                   (~ 
                                                    ((5U 
                                                      >= 
                                                      (7U 
                                                       & ((IData)(3U) 
                                                          + 
                                                          (0xfU 
                                                           & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                              >> 8U))))) 
                                                     && (1U 
                                                         & ((IData)(vlSelf->opl3__DOT__channels__DOT__connection_sel) 
                                                            >> 
                                                            (7U 
                                                             & ((IData)(3U) 
                                                                + 
                                                                (0xfU 
                                                                 & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                                    >> 8U)))))))) 
                                                   << 2U))));
                        vlSelf->opl3__DOT__channels__DOT__signals 
                            = ((0x3ffffffdU & vlSelf->opl3__DOT__channels__DOT__signals) 
                               | (2U & (((IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob) 
                                         >> 5U) & (
                                                   (~ 
                                                    ((5U 
                                                      >= 
                                                      (7U 
                                                       & ((IData)(3U) 
                                                          + 
                                                          (0xfU 
                                                           & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                              >> 8U))))) 
                                                     && (1U 
                                                         & ((IData)(vlSelf->opl3__DOT__channels__DOT__connection_sel) 
                                                            >> 
                                                            (7U 
                                                             & ((IData)(3U) 
                                                                + 
                                                                (0xfU 
                                                                 & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                                    >> 8U)))))))) 
                                                   << 1U))));
                        vlSelf->opl3__DOT__channels__DOT__signals 
                            = ((0x3ffffffeU & vlSelf->opl3__DOT__channels__DOT__signals) 
                               | (IData)((((IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob) 
                                           >> 7U) & 
                                          (~ ((5U >= 
                                               (7U 
                                                & ((IData)(3U) 
                                                   + 
                                                   (0xfU 
                                                    & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                       >> 8U))))) 
                                              && (1U 
                                                  & ((IData)(vlSelf->opl3__DOT__channels__DOT__connection_sel) 
                                                     >> 
                                                     (7U 
                                                      & ((IData)(3U) 
                                                         + 
                                                         (0xfU 
                                                          & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                             >> 8U)))))))))));
                    } else {
                        vlSelf->opl3__DOT__channels__DOT__signals 
                            = ((0x3ffffff7U & vlSelf->opl3__DOT__channels__DOT__signals) 
                               | (8U & (((~ (IData)(vlSelf->opl3__DOT__channels__DOT__is_new)) 
                                         << 3U) | (0x7ffffff8U 
                                                   & (((IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob) 
                                                       >> 1U) 
                                                      & ((~ 
                                                          ((5U 
                                                            >= 
                                                            (7U 
                                                             & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                                >> 8U))) 
                                                           && (1U 
                                                               & ((IData)(vlSelf->opl3__DOT__channels__DOT__connection_sel) 
                                                                  >> 
                                                                  (7U 
                                                                   & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                                      >> 8U)))))) 
                                                         << 3U))))));
                        vlSelf->opl3__DOT__channels__DOT__signals 
                            = ((0x3ffffffbU & vlSelf->opl3__DOT__channels__DOT__signals) 
                               | (4U & (((~ (IData)(vlSelf->opl3__DOT__channels__DOT__is_new)) 
                                         << 2U) | (0x1ffffffcU 
                                                   & (((IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob) 
                                                       >> 3U) 
                                                      & ((~ 
                                                          ((5U 
                                                            >= 
                                                            (7U 
                                                             & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                                >> 8U))) 
                                                           && (1U 
                                                               & ((IData)(vlSelf->opl3__DOT__channels__DOT__connection_sel) 
                                                                  >> 
                                                                  (7U 
                                                                   & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                                      >> 8U)))))) 
                                                         << 2U))))));
                        vlSelf->opl3__DOT__channels__DOT__signals 
                            = ((0x3ffffffdU & vlSelf->opl3__DOT__channels__DOT__signals) 
                               | (2U & (((~ (IData)(vlSelf->opl3__DOT__channels__DOT__is_new)) 
                                         << 1U) | (0x7fffffeU 
                                                   & (((IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob) 
                                                       >> 5U) 
                                                      & ((~ 
                                                          ((5U 
                                                            >= 
                                                            (7U 
                                                             & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                                >> 8U))) 
                                                           && (1U 
                                                               & ((IData)(vlSelf->opl3__DOT__channels__DOT__connection_sel) 
                                                                  >> 
                                                                  (7U 
                                                                   & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                                      >> 8U)))))) 
                                                         << 1U))))));
                        vlSelf->opl3__DOT__channels__DOT__signals 
                            = ((0x3ffffffeU & vlSelf->opl3__DOT__channels__DOT__signals) 
                               | (1U & ((~ (IData)(vlSelf->opl3__DOT__channels__DOT__is_new)) 
                                        | (((IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob) 
                                            >> 7U) 
                                           & (~ ((5U 
                                                  >= 
                                                  (7U 
                                                   & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                      >> 8U))) 
                                                 && (1U 
                                                     & ((IData)(vlSelf->opl3__DOT__channels__DOT__connection_sel) 
                                                        >> 
                                                        (7U 
                                                         & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                            >> 8U))))))))));
                    }
                } else if ((6U > (0xfU & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                          >> 8U)))) {
                    if ((0x20000U & vlSelf->opl3__DOT__channels__DOT__self[1U])) {
                        vlSelf->opl3__DOT__channels__DOT__signals 
                            = ((0x3ffffff7U & vlSelf->opl3__DOT__channels__DOT__signals) 
                               | (8U & (((IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob) 
                                         >> 1U) & (
                                                   (~ 
                                                    ((5U 
                                                      >= 
                                                      (7U 
                                                       & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                          >> 8U))) 
                                                     && (1U 
                                                         & ((IData)(vlSelf->opl3__DOT__channels__DOT__connection_sel) 
                                                            >> 
                                                            (7U 
                                                             & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                                >> 8U)))))) 
                                                   << 3U))));
                        vlSelf->opl3__DOT__channels__DOT__signals 
                            = ((0x3ffffffbU & vlSelf->opl3__DOT__channels__DOT__signals) 
                               | (4U & (((IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob) 
                                         >> 3U) & (
                                                   (~ 
                                                    ((5U 
                                                      >= 
                                                      (7U 
                                                       & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                          >> 8U))) 
                                                     && (1U 
                                                         & ((IData)(vlSelf->opl3__DOT__channels__DOT__connection_sel) 
                                                            >> 
                                                            (7U 
                                                             & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                                >> 8U)))))) 
                                                   << 2U))));
                        vlSelf->opl3__DOT__channels__DOT__signals 
                            = ((0x3ffffffdU & vlSelf->opl3__DOT__channels__DOT__signals) 
                               | (2U & (((IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob) 
                                         >> 5U) & (
                                                   (~ 
                                                    ((5U 
                                                      >= 
                                                      (7U 
                                                       & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                          >> 8U))) 
                                                     && (1U 
                                                         & ((IData)(vlSelf->opl3__DOT__channels__DOT__connection_sel) 
                                                            >> 
                                                            (7U 
                                                             & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                                >> 8U)))))) 
                                                   << 1U))));
                        vlSelf->opl3__DOT__channels__DOT__signals 
                            = ((0x3ffffffeU & vlSelf->opl3__DOT__channels__DOT__signals) 
                               | (IData)((((IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob) 
                                           >> 7U) & 
                                          (~ ((5U >= 
                                               (7U 
                                                & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                   >> 8U))) 
                                              && (1U 
                                                  & ((IData)(vlSelf->opl3__DOT__channels__DOT__connection_sel) 
                                                     >> 
                                                     (7U 
                                                      & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                         >> 8U)))))))));
                    } else {
                        vlSelf->opl3__DOT__channels__DOT__signals 
                            = ((0x3ffffff7U & vlSelf->opl3__DOT__channels__DOT__signals) 
                               | (8U & (((~ (IData)(vlSelf->opl3__DOT__channels__DOT__is_new)) 
                                         << 3U) | (0x7ffffff8U 
                                                   & (((IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob) 
                                                       >> 1U) 
                                                      & ((~ 
                                                          ((5U 
                                                            >= 
                                                            (7U 
                                                             & ((0xfU 
                                                                 & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                                    >> 8U)) 
                                                                - (IData)(3U)))) 
                                                           && (1U 
                                                               & ((IData)(vlSelf->opl3__DOT__channels__DOT__connection_sel) 
                                                                  >> 
                                                                  (7U 
                                                                   & ((0xfU 
                                                                       & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                                          >> 8U)) 
                                                                      - (IData)(3U))))))) 
                                                         << 3U))))));
                        vlSelf->opl3__DOT__channels__DOT__signals 
                            = ((0x3ffffffbU & vlSelf->opl3__DOT__channels__DOT__signals) 
                               | (4U & (((~ (IData)(vlSelf->opl3__DOT__channels__DOT__is_new)) 
                                         << 2U) | (0x1ffffffcU 
                                                   & (((IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob) 
                                                       >> 3U) 
                                                      & ((~ 
                                                          ((5U 
                                                            >= 
                                                            (7U 
                                                             & ((0xfU 
                                                                 & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                                    >> 8U)) 
                                                                - (IData)(3U)))) 
                                                           && (1U 
                                                               & ((IData)(vlSelf->opl3__DOT__channels__DOT__connection_sel) 
                                                                  >> 
                                                                  (7U 
                                                                   & ((0xfU 
                                                                       & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                                          >> 8U)) 
                                                                      - (IData)(3U))))))) 
                                                         << 2U))))));
                        vlSelf->opl3__DOT__channels__DOT__signals 
                            = ((0x3ffffffdU & vlSelf->opl3__DOT__channels__DOT__signals) 
                               | (2U & (((~ (IData)(vlSelf->opl3__DOT__channels__DOT__is_new)) 
                                         << 1U) | (0x7fffffeU 
                                                   & (((IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob) 
                                                       >> 5U) 
                                                      & ((~ 
                                                          ((5U 
                                                            >= 
                                                            (7U 
                                                             & ((0xfU 
                                                                 & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                                    >> 8U)) 
                                                                - (IData)(3U)))) 
                                                           && (1U 
                                                               & ((IData)(vlSelf->opl3__DOT__channels__DOT__connection_sel) 
                                                                  >> 
                                                                  (7U 
                                                                   & ((0xfU 
                                                                       & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                                          >> 8U)) 
                                                                      - (IData)(3U))))))) 
                                                         << 1U))))));
                        vlSelf->opl3__DOT__channels__DOT__signals 
                            = ((0x3ffffffeU & vlSelf->opl3__DOT__channels__DOT__signals) 
                               | (1U & ((~ (IData)(vlSelf->opl3__DOT__channels__DOT__is_new)) 
                                        | (((IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob) 
                                            >> 7U) 
                                           & (~ ((5U 
                                                  >= 
                                                  (7U 
                                                   & ((0xfU 
                                                       & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                          >> 8U)) 
                                                      - (IData)(3U)))) 
                                                 && (1U 
                                                     & ((IData)(vlSelf->opl3__DOT__channels__DOT__connection_sel) 
                                                        >> 
                                                        (7U 
                                                         & ((0xfU 
                                                             & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                                >> 8U)) 
                                                            - (IData)(3U)))))))))));
                    }
                } else {
                    vlSelf->opl3__DOT__channels__DOT__signals 
                        = ((0x3ffffff7U & vlSelf->opl3__DOT__channels__DOT__signals) 
                           | (8U & ((((~ (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                          >> 0x11U)) 
                                      & (~ (IData)(vlSelf->opl3__DOT__channels__DOT__is_new))) 
                                     << 3U) | (0x7ffffff8U 
                                               & ((IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob) 
                                                  >> 1U)))));
                    vlSelf->opl3__DOT__channels__DOT__signals 
                        = ((0x3ffffffbU & vlSelf->opl3__DOT__channels__DOT__signals) 
                           | (4U & ((((~ (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                          >> 0x11U)) 
                                      & (~ (IData)(vlSelf->opl3__DOT__channels__DOT__is_new))) 
                                     << 2U) | (0x1ffffffcU 
                                               & ((IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob) 
                                                  >> 3U)))));
                    vlSelf->opl3__DOT__channels__DOT__signals 
                        = ((0x3ffffffdU & vlSelf->opl3__DOT__channels__DOT__signals) 
                           | (2U & ((((~ (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                          >> 0x11U)) 
                                      & (~ (IData)(vlSelf->opl3__DOT__channels__DOT__is_new))) 
                                     << 1U) | (0x7fffffeU 
                                               & ((IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob) 
                                                  >> 5U)))));
                    vlSelf->opl3__DOT__channels__DOT__signals 
                        = ((0x3ffffffeU & vlSelf->opl3__DOT__channels__DOT__signals) 
                           | (1U & (((~ (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                         >> 0x11U)) 
                                     & (~ (IData)(vlSelf->opl3__DOT__channels__DOT__is_new))) 
                                    | ((IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob) 
                                       >> 7U))));
                }
                if (((1U == ((2U & (vlSelf->opl3__DOT__channels__DOT__signals 
                                    >> 2U)) | (1U & 
                                               (vlSelf->opl3__DOT__channels__DOT__signals 
                                                >> 1U)))) 
                     || (2U == ((2U & (vlSelf->opl3__DOT__channels__DOT__signals 
                                       >> 2U)) | (1U 
                                                  & (vlSelf->opl3__DOT__channels__DOT__signals 
                                                     >> 1U)))))) {
                    vlSelf->opl3__DOT__channels__DOT__next_self[0U] 
                        = ((0xfffffU & vlSelf->opl3__DOT__channels__DOT__next_self[0U]) 
                           | ((((vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                 << 0xcU) | (vlSelf->opl3__DOT__channels__DOT__self[0U] 
                                             >> 0x14U)) 
                               + VL_EXTENDS_II(20,15, 
                                               (0x7fffU 
                                                & (vlSelf->opl3__DOT__channels__DOT__signals 
                                                   >> 5U)))) 
                              << 0x14U));
                    vlSelf->opl3__DOT__channels__DOT__next_self[1U] 
                        = ((0xffffff00U & vlSelf->opl3__DOT__channels__DOT__next_self[1U]) 
                           | (0xffU & ((((vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                          << 0xcU) 
                                         | (vlSelf->opl3__DOT__channels__DOT__self[0U] 
                                            >> 0x14U)) 
                                        + VL_EXTENDS_II(20,15, 
                                                        (0x7fffU 
                                                         & (vlSelf->opl3__DOT__channels__DOT__signals 
                                                            >> 5U)))) 
                                       >> 0xcU)));
                } else if ((3U == ((2U & (vlSelf->opl3__DOT__channels__DOT__signals 
                                          >> 2U)) | 
                                   (1U & (vlSelf->opl3__DOT__channels__DOT__signals 
                                          >> 1U))))) {
                    vlSelf->opl3__DOT__channels__DOT__next_self[0U] 
                        = ((0xfffffU & vlSelf->opl3__DOT__channels__DOT__next_self[0U]) 
                           | ((VL_EXTENDS_II(20,20, 
                                             (0xfffffU 
                                              & ((vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                  << 0xcU) 
                                                 | (vlSelf->opl3__DOT__channels__DOT__self[0U] 
                                                    >> 0x14U)))) 
                               + VL_MULS_III(32, (IData)(2U), 
                                             VL_EXTENDS_II(32,15, 
                                                           (0x7fffU 
                                                            & (vlSelf->opl3__DOT__channels__DOT__signals 
                                                               >> 5U))))) 
                              << 0x14U));
                    vlSelf->opl3__DOT__channels__DOT__next_self[1U] 
                        = ((0xffffff00U & vlSelf->opl3__DOT__channels__DOT__next_self[1U]) 
                           | (0xffU & ((VL_EXTENDS_II(20,20, 
                                                      (0xfffffU 
                                                       & ((vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                           << 0xcU) 
                                                          | (vlSelf->opl3__DOT__channels__DOT__self[0U] 
                                                             >> 0x14U)))) 
                                        + VL_MULS_III(32, (IData)(2U), 
                                                      VL_EXTENDS_II(32,15, 
                                                                    (0x7fffU 
                                                                     & (vlSelf->opl3__DOT__channels__DOT__signals 
                                                                        >> 5U))))) 
                                       >> 0xcU)));
                }
                if (((1U == ((2U & (vlSelf->opl3__DOT__channels__DOT__signals 
                                    >> 1U)) | (1U & vlSelf->opl3__DOT__channels__DOT__signals))) 
                     || (2U == ((2U & (vlSelf->opl3__DOT__channels__DOT__signals 
                                       >> 1U)) | (1U 
                                                  & vlSelf->opl3__DOT__channels__DOT__signals))))) {
                    vlSelf->opl3__DOT__channels__DOT__next_self[0U] 
                        = ((0xfff00000U & vlSelf->opl3__DOT__channels__DOT__next_self[0U]) 
                           | (0xfffffU & (vlSelf->opl3__DOT__channels__DOT__self[0U] 
                                          + VL_EXTENDS_II(20,15, 
                                                          (0x7fffU 
                                                           & (vlSelf->opl3__DOT__channels__DOT__signals 
                                                              >> 5U))))));
                } else if ((3U == ((2U & (vlSelf->opl3__DOT__channels__DOT__signals 
                                          >> 1U)) | 
                                   (1U & vlSelf->opl3__DOT__channels__DOT__signals)))) {
                    vlSelf->opl3__DOT__channels__DOT__next_self[0U] 
                        = ((0xfff00000U & vlSelf->opl3__DOT__channels__DOT__next_self[0U]) 
                           | (0xfffffU & (VL_EXTENDS_II(20,20, 
                                                        (0xfffffU 
                                                         & vlSelf->opl3__DOT__channels__DOT__self[0U])) 
                                          + VL_MULS_III(32, (IData)(2U), 
                                                        VL_EXTENDS_II(32,15, 
                                                                      (0x7fffU 
                                                                       & (vlSelf->opl3__DOT__channels__DOT__signals 
                                                                          >> 5U)))))));
                }
                if ((8U == (0xfU & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                    >> 8U)))) {
                    vlSelf->opl3__DOT__channels__DOT__next_self[1U] 
                        = ((0xfffc00ffU & vlSelf->opl3__DOT__channels__DOT__next_self[1U]) 
                           | (((0x20000U & vlSelf->opl3__DOT__channels__DOT__self[1U])
                                ? 0U : 0x200U) << 8U));
                } else {
                    vlSelf->opl3__DOT__channels__DOT__next_self[1U] 
                        = ((0xfffe0fffU & vlSelf->opl3__DOT__channels__DOT__next_self[1U]) 
                           | (((2U == (0xfU & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                               >> 8U)))
                                ? 6U : ((5U == (0xfU 
                                                & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                   >> 8U)))
                                         ? 0xcU : (0x1fU 
                                                   & ((IData)(1U) 
                                                      + 
                                                      ((vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                        << 0x14U) 
                                                       | (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                          >> 0xcU)))))) 
                              << 0xcU));
                    vlSelf->opl3__DOT__channels__DOT__next_self[1U] 
                        = ((0xfffff0ffU & vlSelf->opl3__DOT__channels__DOT__next_self[1U]) 
                           | (0xf00U & (((IData)(1U) 
                                         + ((vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                             << 0x18U) 
                                            | (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                               >> 8U))) 
                                        << 8U)));
                }
            } else if ((4U == vlSelf->opl3__DOT__channels__DOT__state)) {
                vlSelf->opl3__DOT__channels__DOT__signals 
                    = ((0x1ffffffU & vlSelf->opl3__DOT__channels__DOT__signals) 
                       | (0x3e000000U & (((IData)(9U) 
                                          + (0xfU & 
                                             (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                              >> 8U))) 
                                         << 0x19U)));
                vlSelf->opl3__DOT__channels__DOT__signals 
                    = (0x1000000U | vlSelf->opl3__DOT__channels__DOT__signals);
            } else if ((5U == vlSelf->opl3__DOT__channels__DOT__state)) {
                vlSelf->opl3__DOT__channels__DOT__signals 
                    = ((0x1ffffffU & vlSelf->opl3__DOT__channels__DOT__signals) 
                       | (0x3e000000U & (((IData)(6U) 
                                          + (0xfU & 
                                             (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                              >> 8U))) 
                                         << 0x19U)));
                vlSelf->opl3__DOT__channels__DOT__next_self[1U] 
                    = ((0x7fffffffU & vlSelf->opl3__DOT__channels__DOT__next_self[1U]) 
                       | ((IData)(vlSelf->opl3__DOT__channels__DOT__operator_mem_out) 
                          << 0x1fU));
                vlSelf->opl3__DOT__channels__DOT__next_self[2U] 
                    = ((0x1000U & vlSelf->opl3__DOT__channels__DOT__next_self[2U]) 
                       | (0x1fffU & ((IData)(vlSelf->opl3__DOT__channels__DOT__operator_mem_out) 
                                     >> 1U)));
                vlSelf->opl3__DOT__channels__DOT__signals 
                    = (0x1000000U | vlSelf->opl3__DOT__channels__DOT__signals);
                vlSelf->opl3__DOT__channels__DOT__next_self[2U] 
                    = ((0xfffU & vlSelf->opl3__DOT__channels__DOT__next_self[2U]) 
                       | (0x1000U & ((IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob) 
                                     << 0xcU)));
                vlSelf->opl3__DOT__channels__DOT__signals 
                    = ((0x3f0fffffU & vlSelf->opl3__DOT__channels__DOT__signals) 
                       | (0xf00000U & (((IData)(3U) 
                                        + ((vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                            << 0x18U) 
                                           | (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                              >> 8U))) 
                                       << 0x14U)));
            } else if ((6U == vlSelf->opl3__DOT__channels__DOT__state)) {
                vlSelf->opl3__DOT__channels__DOT__signals 
                    = ((0x3f0fffffU & vlSelf->opl3__DOT__channels__DOT__signals) 
                       | (0xf00000U & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                       << 0xcU)));
                vlSelf->opl3__DOT__channels__DOT__next_self[1U] 
                    = ((0x8003ffffU & vlSelf->opl3__DOT__channels__DOT__next_self[1U]) 
                       | ((IData)(vlSelf->opl3__DOT__channels__DOT__operator_mem_out) 
                          << 0x12U));
                vlSelf->opl3__DOT__channels__DOT__signals 
                    = ((0x1ffffffU & vlSelf->opl3__DOT__channels__DOT__signals) 
                       | (0x3e000000U & (((1U == ((2U 
                                                   & ((IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob) 
                                                      << 1U)) 
                                                  | (1U 
                                                     & (vlSelf->opl3__DOT__channels__DOT__self[2U] 
                                                        >> 0xcU))))
                                           ? ((IData)(3U) 
                                              + (0xfU 
                                                 & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                    >> 8U)))
                                           : (0xfU 
                                              & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                 >> 8U))) 
                                         << 0x19U)));
                vlSelf->opl3__DOT__channels__DOT__signals 
                    = (0x1000000U | vlSelf->opl3__DOT__channels__DOT__signals);
            } else {
                vlSelf->opl3__DOT__channels__DOT__signals 
                    = ((0x3f0fffffU & vlSelf->opl3__DOT__channels__DOT__signals) 
                       | (0xf00000U & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                       << 0xcU)));
                if ((0U == ((2U & ((IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob) 
                                   << 1U)) | (1U & 
                                              (vlSelf->opl3__DOT__channels__DOT__self[2U] 
                                               >> 0xcU))))) {
                    vlSelf->opl3__DOT__channels__DOT__signals 
                        = ((0x3ff0001fU & vlSelf->opl3__DOT__channels__DOT__signals) 
                           | (0xfffe0U & (VL_EXTENDS_II(15,13, 
                                                        (0x1fffU 
                                                         & ((vlSelf->opl3__DOT__channels__DOT__self[2U] 
                                                             << 1U) 
                                                            | (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                               >> 0x1fU)))) 
                                          << 5U)));
                } else if ((1U == ((2U & ((IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob) 
                                          << 1U)) | 
                                   (1U & (vlSelf->opl3__DOT__channels__DOT__self[2U] 
                                          >> 0xcU))))) {
                    vlSelf->opl3__DOT__channels__DOT__signals 
                        = ((0x3ff0001fU & vlSelf->opl3__DOT__channels__DOT__signals) 
                           | (0xfffe0U & ((VL_EXTENDS_II(15,13, (IData)(vlSelf->opl3__DOT__channels__DOT__operator_mem_out)) 
                                           + VL_EXTENDS_II(15,13, 
                                                           (0x1fffU 
                                                            & ((vlSelf->opl3__DOT__channels__DOT__self[2U] 
                                                                << 1U) 
                                                               | (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                                  >> 0x1fU))))) 
                                          << 5U)));
                } else if ((2U == ((2U & ((IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob) 
                                          << 1U)) | 
                                   (1U & (vlSelf->opl3__DOT__channels__DOT__self[2U] 
                                          >> 0xcU))))) {
                    vlSelf->opl3__DOT__channels__DOT__signals 
                        = ((0x3ff0001fU & vlSelf->opl3__DOT__channels__DOT__signals) 
                           | (0xfffe0U & ((VL_EXTENDS_II(15,13, (IData)(vlSelf->opl3__DOT__channels__DOT__operator_mem_out)) 
                                           + VL_EXTENDS_II(15,13, 
                                                           (0x1fffU 
                                                            & ((vlSelf->opl3__DOT__channels__DOT__self[2U] 
                                                                << 1U) 
                                                               | (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                                  >> 0x1fU))))) 
                                          << 5U)));
                } else if ((3U == ((2U & ((IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob) 
                                          << 1U)) | 
                                   (1U & (vlSelf->opl3__DOT__channels__DOT__self[2U] 
                                          >> 0xcU))))) {
                    vlSelf->opl3__DOT__channels__DOT__signals 
                        = ((0x3ff0001fU & vlSelf->opl3__DOT__channels__DOT__signals) 
                           | (0xfffe0U & (((VL_EXTENDS_II(15,13, (IData)(vlSelf->opl3__DOT__channels__DOT__operator_mem_out)) 
                                            + VL_EXTENDS_II(15,13, 
                                                            (0x1fffU 
                                                             & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                                >> 0x12U)))) 
                                           + VL_EXTENDS_II(15,13, 
                                                           (0x1fffU 
                                                            & ((vlSelf->opl3__DOT__channels__DOT__self[2U] 
                                                                << 1U) 
                                                               | (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                                  >> 0x1fU))))) 
                                          << 5U)));
                }
                if ((0x20000U & vlSelf->opl3__DOT__channels__DOT__self[1U])) {
                    vlSelf->opl3__DOT__channels__DOT__signals 
                        = ((0x3ffffff7U & vlSelf->opl3__DOT__channels__DOT__signals) 
                           | (0x7ffffff8U & (((IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob) 
                                              >> 1U) 
                                             & (((5U 
                                                  >= 
                                                  (7U 
                                                   & ((IData)(3U) 
                                                      + 
                                                      (0xfU 
                                                       & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                          >> 8U))))) 
                                                 && (1U 
                                                     & ((IData)(vlSelf->opl3__DOT__channels__DOT__connection_sel) 
                                                        >> 
                                                        (7U 
                                                         & ((IData)(3U) 
                                                            + 
                                                            (0xfU 
                                                             & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                                >> 8U))))))) 
                                                << 3U))));
                    vlSelf->opl3__DOT__channels__DOT__signals 
                        = ((0x3ffffffbU & vlSelf->opl3__DOT__channels__DOT__signals) 
                           | (0x1ffffffcU & (((IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob) 
                                              >> 3U) 
                                             & (((5U 
                                                  >= 
                                                  (7U 
                                                   & ((IData)(3U) 
                                                      + 
                                                      (0xfU 
                                                       & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                          >> 8U))))) 
                                                 && (1U 
                                                     & ((IData)(vlSelf->opl3__DOT__channels__DOT__connection_sel) 
                                                        >> 
                                                        (7U 
                                                         & ((IData)(3U) 
                                                            + 
                                                            (0xfU 
                                                             & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                                >> 8U))))))) 
                                                << 2U))));
                    vlSelf->opl3__DOT__channels__DOT__signals 
                        = ((0x3ffffffdU & vlSelf->opl3__DOT__channels__DOT__signals) 
                           | (0x7fffffeU & (((IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob) 
                                             >> 5U) 
                                            & (((5U 
                                                 >= 
                                                 (7U 
                                                  & ((IData)(3U) 
                                                     + 
                                                     (0xfU 
                                                      & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                         >> 8U))))) 
                                                && (1U 
                                                    & ((IData)(vlSelf->opl3__DOT__channels__DOT__connection_sel) 
                                                       >> 
                                                       (7U 
                                                        & ((IData)(3U) 
                                                           + 
                                                           (0xfU 
                                                            & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                               >> 8U))))))) 
                                               << 1U))));
                    vlSelf->opl3__DOT__channels__DOT__signals 
                        = ((0x3ffffffeU & vlSelf->opl3__DOT__channels__DOT__signals) 
                           | (((IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob) 
                               >> 7U) & ((5U >= (7U 
                                                 & ((IData)(3U) 
                                                    + 
                                                    (0xfU 
                                                     & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                        >> 8U))))) 
                                         && (1U & ((IData)(vlSelf->opl3__DOT__channels__DOT__connection_sel) 
                                                   >> 
                                                   (7U 
                                                    & ((IData)(3U) 
                                                       + 
                                                       (0xfU 
                                                        & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                           >> 8U)))))))));
                } else {
                    vlSelf->opl3__DOT__channels__DOT__signals 
                        = ((0x3ffffff7U & vlSelf->opl3__DOT__channels__DOT__signals) 
                           | (0x7ffffff8U & (((IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob) 
                                              >> 1U) 
                                             & (((5U 
                                                  >= 
                                                  (7U 
                                                   & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                      >> 8U))) 
                                                 && (1U 
                                                     & ((IData)(vlSelf->opl3__DOT__channels__DOT__connection_sel) 
                                                        >> 
                                                        (7U 
                                                         & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                            >> 8U))))) 
                                                << 3U))));
                    vlSelf->opl3__DOT__channels__DOT__signals 
                        = ((0x3ffffffbU & vlSelf->opl3__DOT__channels__DOT__signals) 
                           | (0x1ffffffcU & (((IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob) 
                                              >> 3U) 
                                             & (((5U 
                                                  >= 
                                                  (7U 
                                                   & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                      >> 8U))) 
                                                 && (1U 
                                                     & ((IData)(vlSelf->opl3__DOT__channels__DOT__connection_sel) 
                                                        >> 
                                                        (7U 
                                                         & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                            >> 8U))))) 
                                                << 2U))));
                    vlSelf->opl3__DOT__channels__DOT__signals 
                        = ((0x3ffffffdU & vlSelf->opl3__DOT__channels__DOT__signals) 
                           | (0x7fffffeU & (((IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob) 
                                             >> 5U) 
                                            & (((5U 
                                                 >= 
                                                 (7U 
                                                  & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                     >> 8U))) 
                                                && (1U 
                                                    & ((IData)(vlSelf->opl3__DOT__channels__DOT__connection_sel) 
                                                       >> 
                                                       (7U 
                                                        & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                           >> 8U))))) 
                                               << 1U))));
                    vlSelf->opl3__DOT__channels__DOT__signals 
                        = ((0x3ffffffeU & vlSelf->opl3__DOT__channels__DOT__signals) 
                           | (((IData)(vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob) 
                               >> 7U) & ((5U >= (7U 
                                                 & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                    >> 8U))) 
                                         && (1U & ((IData)(vlSelf->opl3__DOT__channels__DOT__connection_sel) 
                                                   >> 
                                                   (7U 
                                                    & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                       >> 8U)))))));
                }
                if (((1U == ((2U & (vlSelf->opl3__DOT__channels__DOT__signals 
                                    >> 2U)) | (1U & 
                                               (vlSelf->opl3__DOT__channels__DOT__signals 
                                                >> 1U)))) 
                     || (2U == ((2U & (vlSelf->opl3__DOT__channels__DOT__signals 
                                       >> 2U)) | (1U 
                                                  & (vlSelf->opl3__DOT__channels__DOT__signals 
                                                     >> 1U)))))) {
                    vlSelf->opl3__DOT__channels__DOT__next_self[0U] 
                        = ((0xfffffU & vlSelf->opl3__DOT__channels__DOT__next_self[0U]) 
                           | ((((vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                 << 0xcU) | (vlSelf->opl3__DOT__channels__DOT__self[0U] 
                                             >> 0x14U)) 
                               + VL_EXTENDS_II(20,15, 
                                               (0x7fffU 
                                                & (vlSelf->opl3__DOT__channels__DOT__signals 
                                                   >> 5U)))) 
                              << 0x14U));
                    vlSelf->opl3__DOT__channels__DOT__next_self[1U] 
                        = ((0xffffff00U & vlSelf->opl3__DOT__channels__DOT__next_self[1U]) 
                           | (0xffU & ((((vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                          << 0xcU) 
                                         | (vlSelf->opl3__DOT__channels__DOT__self[0U] 
                                            >> 0x14U)) 
                                        + VL_EXTENDS_II(20,15, 
                                                        (0x7fffU 
                                                         & (vlSelf->opl3__DOT__channels__DOT__signals 
                                                            >> 5U)))) 
                                       >> 0xcU)));
                } else if ((3U == ((2U & (vlSelf->opl3__DOT__channels__DOT__signals 
                                          >> 2U)) | 
                                   (1U & (vlSelf->opl3__DOT__channels__DOT__signals 
                                          >> 1U))))) {
                    vlSelf->opl3__DOT__channels__DOT__next_self[0U] 
                        = ((0xfffffU & vlSelf->opl3__DOT__channels__DOT__next_self[0U]) 
                           | ((VL_EXTENDS_II(20,20, 
                                             (0xfffffU 
                                              & ((vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                  << 0xcU) 
                                                 | (vlSelf->opl3__DOT__channels__DOT__self[0U] 
                                                    >> 0x14U)))) 
                               + VL_MULS_III(32, (IData)(2U), 
                                             VL_EXTENDS_II(32,15, 
                                                           (0x7fffU 
                                                            & (vlSelf->opl3__DOT__channels__DOT__signals 
                                                               >> 5U))))) 
                              << 0x14U));
                    vlSelf->opl3__DOT__channels__DOT__next_self[1U] 
                        = ((0xffffff00U & vlSelf->opl3__DOT__channels__DOT__next_self[1U]) 
                           | (0xffU & ((VL_EXTENDS_II(20,20, 
                                                      (0xfffffU 
                                                       & ((vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                           << 0xcU) 
                                                          | (vlSelf->opl3__DOT__channels__DOT__self[0U] 
                                                             >> 0x14U)))) 
                                        + VL_MULS_III(32, (IData)(2U), 
                                                      VL_EXTENDS_II(32,15, 
                                                                    (0x7fffU 
                                                                     & (vlSelf->opl3__DOT__channels__DOT__signals 
                                                                        >> 5U))))) 
                                       >> 0xcU)));
                }
                if (((1U == ((2U & (vlSelf->opl3__DOT__channels__DOT__signals 
                                    >> 1U)) | (1U & vlSelf->opl3__DOT__channels__DOT__signals))) 
                     || (2U == ((2U & (vlSelf->opl3__DOT__channels__DOT__signals 
                                       >> 1U)) | (1U 
                                                  & vlSelf->opl3__DOT__channels__DOT__signals))))) {
                    vlSelf->opl3__DOT__channels__DOT__next_self[0U] 
                        = ((0xfff00000U & vlSelf->opl3__DOT__channels__DOT__next_self[0U]) 
                           | (0xfffffU & (vlSelf->opl3__DOT__channels__DOT__self[0U] 
                                          + VL_EXTENDS_II(20,15, 
                                                          (0x7fffU 
                                                           & (vlSelf->opl3__DOT__channels__DOT__signals 
                                                              >> 5U))))));
                } else if ((3U == ((2U & (vlSelf->opl3__DOT__channels__DOT__signals 
                                          >> 1U)) | 
                                   (1U & vlSelf->opl3__DOT__channels__DOT__signals)))) {
                    vlSelf->opl3__DOT__channels__DOT__next_self[0U] 
                        = ((0xfff00000U & vlSelf->opl3__DOT__channels__DOT__next_self[0U]) 
                           | (0xfffffU & (VL_EXTENDS_II(20,20, 
                                                        (0xfffffU 
                                                         & vlSelf->opl3__DOT__channels__DOT__self[0U])) 
                                          + VL_MULS_III(32, (IData)(2U), 
                                                        VL_EXTENDS_II(32,15, 
                                                                      (0x7fffU 
                                                                       & (vlSelf->opl3__DOT__channels__DOT__signals 
                                                                          >> 5U)))))));
                }
                if ((2U == (0xfU & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                    >> 8U)))) {
                    if ((1U & (~ (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                  >> 0x11U)))) {
                        vlSelf->opl3__DOT__channels__DOT__next_self[1U] 
                            = (0xfffff0ffU & vlSelf->opl3__DOT__channels__DOT__next_self[1U]);
                        vlSelf->opl3__DOT__channels__DOT__next_self[1U] 
                            = (0x20000U | vlSelf->opl3__DOT__channels__DOT__next_self[1U]);
                    }
                } else {
                    vlSelf->opl3__DOT__channels__DOT__next_self[1U] 
                        = ((0xfffff0ffU & vlSelf->opl3__DOT__channels__DOT__next_self[1U]) 
                           | (0xf00U & (((IData)(1U) 
                                         + ((vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                             << 0x18U) 
                                            | (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                               >> 8U))) 
                                        << 8U)));
                }
            }
        }
    } else if ((8U == vlSelf->opl3__DOT__channels__DOT__state)) {
        vlSelf->opl3__DOT__channels__DOT__next_self[0U] = 0U;
        vlSelf->opl3__DOT__channels__DOT__next_self[1U] = 0U;
        vlSelf->opl3__DOT__channels__DOT__next_self[2U] = 0U;
        vlSelf->opl3__DOT__channels__DOT__signals = 
            (0x10U | vlSelf->opl3__DOT__channels__DOT__signals);
    }
    if ((8U >= (0xfU & (vlSelf->opl3__DOT__channels__DOT__signals 
                        >> 0x14U)))) {
        vlSelf->opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__dob_array[0U] 
            = vlSelf->opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram
            [(0xfU & (vlSelf->opl3__DOT__channels__DOT__signals 
                      >> 0x14U))];
        vlSelf->opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__dob_array[1U] 
            = vlSelf->opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram
            [(0xfU & (vlSelf->opl3__DOT__channels__DOT__signals 
                      >> 0x14U))];
    } else {
        vlSelf->opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__dob_array[0U] = 0U;
        vlSelf->opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__dob_array[1U] = 0U;
    }
    vlSelf->opl3__DOT__channels__DOT____Vcellout__ch_abcd_cnt_mem__dob 
        = vlSelf->opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__dob_array
        [(1U & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                >> 0x11U))];
}

void Vopl3___024root___eval_act(Vopl3___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vopl3__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vopl3___024root___eval_act\n"); );
    // Body
    if ((1ULL & vlSelf->__VactTriggered.word(0U))) {
        Vopl3___024root___act_sequent__TOP__0(vlSelf);
    }
}

extern const VlUnpacked<SData/*11:0*/, 256> Vopl3__ConstPool__TABLE_h94f3441f_0;
extern const VlUnpacked<CData/*6:0*/, 16> Vopl3__ConstPool__TABLE_he3797a36_0;
extern const VlUnpacked<SData/*9:0*/, 256> Vopl3__ConstPool__TABLE_h40e95e60_0;
extern const VlUnpacked<CData/*4:0*/, 16> Vopl3__ConstPool__TABLE_hecfd1f27_0;
extern const VlUnpacked<CData/*3:0*/, 4096> Vopl3__ConstPool__TABLE_h38f42766_0;
extern const VlUnpacked<CData/*2:0*/, 4096> Vopl3__ConstPool__TABLE_h0637a799_0;
extern const VlUnpacked<CData/*3:0*/, 4096> Vopl3__ConstPool__TABLE_hc80edecc_0;
extern const VlUnpacked<CData/*3:0*/, 4096> Vopl3__ConstPool__TABLE_h6daf335f_0;

VL_INLINE_OPT void Vopl3___024root___nba_sequent__TOP__0(Vopl3___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vopl3__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vopl3___024root___nba_sequent__TOP__0\n"); );
    // Init
    CData/*0:0*/ opl3__DOT__channels__DOT____Vcellinp__ch_abcd_cnt_mem__wea;
    opl3__DOT__channels__DOT____Vcellinp__ch_abcd_cnt_mem__wea = 0;
    CData/*2:0*/ opl3__DOT__channels__DOT__control_operators__DOT__ws;
    opl3__DOT__channels__DOT__control_operators__DOT__ws = 0;
    CData/*4:0*/ opl3__DOT__channels__DOT__control_operators__DOT__operator_mem_rd_address;
    opl3__DOT__channels__DOT__control_operators__DOT__operator_mem_rd_address = 0;
    CData/*0:0*/ opl3__DOT__channels__DOT__control_operators__DOT__cnt1_p1;
    opl3__DOT__channels__DOT__control_operators__DOT__cnt1_p1 = 0;
    CData/*7:0*/ opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__ar_dr_mem__dob;
    opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__ar_dr_mem__dob = 0;
    CData/*0:0*/ opl3__DOT__channels__DOT__control_operators__DOT____Vcellinp__block_fnum_high_mem__wea;
    opl3__DOT__channels__DOT__control_operators__DOT____Vcellinp__block_fnum_high_mem__wea = 0;
    CData/*3:0*/ opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fb_cnt0_mem__dob;
    opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fb_cnt0_mem__dob = 0;
    IData/*21:0*/ opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_result_tmp_p1;
    opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_result_tmp_p1 = 0;
    CData/*2:0*/ opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT__vibrato__DOT__delta1_p1;
    opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT__vibrato__DOT__delta1_p1 = 0;
    CData/*0:0*/ opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__eg_off_p2;
    opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__eg_off_p2 = 0;
    SData/*11:0*/ opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_extra_bits_p2;
    opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_extra_bits_p2 = 0;
    CData/*4:0*/ opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__sl_increased_p2;
    opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__sl_increased_p2 = 0;
    CData/*3:0*/ opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__block_shifted;
    opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__block_shifted = 0;
    CData/*3:0*/ opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__ksv_p0;
    opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__ksv_p0 = 0;
    CData/*4:0*/ opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__rate_hi_pre_p1;
    opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__rate_hi_pre_p1 = 0;
    SData/*9:0*/ opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__tc_phase_p2;
    opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__tc_phase_p2 = 0;
    SData/*11:0*/ __Vtableidx1;
    __Vtableidx1 = 0;
    CData/*3:0*/ __Vtableidx2;
    __Vtableidx2 = 0;
    CData/*3:0*/ __Vtableidx3;
    __Vtableidx3 = 0;
    CData/*7:0*/ __Vtableidx4;
    __Vtableidx4 = 0;
    CData/*7:0*/ __Vtableidx5;
    __Vtableidx5 = 0;
    CData/*1:0*/ __Vdly__opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__force_timer_overflow_sync__DOT__sync_regs;
    __Vdly__opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__force_timer_overflow_sync__DOT__sync_regs = 0;
    SData/*9:0*/ __Vdly__opl3__DOT__sample_clk_gen__DOT__counter;
    __Vdly__opl3__DOT__sample_clk_gen__DOT__counter = 0;
    CData/*3:0*/ __Vdlyvdim0__opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvdim0__opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*7:0*/ __Vdlyvval__opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvval__opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*0:0*/ __Vdlyvset__opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvset__opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*3:0*/ __Vdlyvdim0__opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvdim0__opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*7:0*/ __Vdlyvval__opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvval__opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*0:0*/ __Vdlyvset__opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvset__opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*4:0*/ __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*7:0*/ __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*0:0*/ __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*4:0*/ __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*7:0*/ __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*0:0*/ __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*4:0*/ __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*7:0*/ __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*0:0*/ __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*4:0*/ __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*7:0*/ __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*0:0*/ __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*4:0*/ __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*7:0*/ __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*0:0*/ __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*4:0*/ __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*7:0*/ __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*0:0*/ __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*4:0*/ __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*7:0*/ __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*0:0*/ __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*4:0*/ __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*7:0*/ __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*0:0*/ __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*4:0*/ __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*2:0*/ __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*0:0*/ __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*4:0*/ __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*2:0*/ __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*0:0*/ __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*3:0*/ __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*7:0*/ __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*0:0*/ __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*3:0*/ __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*7:0*/ __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*0:0*/ __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*3:0*/ __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*0:0*/ __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*0:0*/ __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*3:0*/ __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*0:0*/ __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*0:0*/ __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*3:0*/ __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*4:0*/ __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*0:0*/ __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*3:0*/ __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*4:0*/ __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*0:0*/ __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*3:0*/ __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*3:0*/ __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*0:0*/ __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*3:0*/ __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*3:0*/ __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*0:0*/ __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*3:0*/ __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*0:0*/ __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*0:0*/ __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*3:0*/ __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*0:0*/ __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*0:0*/ __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*5:0*/ __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT____Vcellout__sample_clk_en_sr__out;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT____Vcellout__sample_clk_en_sr__out = 0;
    CData/*1:0*/ __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT____Vcellout__vib_sr__out;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT____Vcellout__vib_sr__out = 0;
    SData/*12:0*/ __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT__vibrato__DOT__vibrato_index_p1;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT__vibrato__DOT__vibrato_index_p1 = 0;
    IData/*17:0*/ __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__tl_p;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__tl_p = 0;
    IData/*26:0*/ __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_p;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_p = 0;
    CData/*2:0*/ __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT____Vcellout__eg_reset_sr__out;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT____Vcellout__eg_reset_sr__out = 0;
    CData/*4:0*/ __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*3:0*/ __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*0:0*/ __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*4:0*/ __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*3:0*/ __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*0:0*/ __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    SData/*12:0*/ __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_timer;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_timer = 0;
    CData/*0:0*/ __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_state;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_state = 0;
    CData/*2:0*/ __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT____Vcellout__sample_clk_en_sr__out;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT____Vcellout__sample_clk_en_sr__out = 0;
    CData/*2:0*/ __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__bank_num_p;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__bank_num_p = 0;
    SData/*14:0*/ __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__op_num_p;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__op_num_p = 0;
    CData/*4:0*/ __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    SData/*8:0*/ __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*0:0*/ __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*4:0*/ __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    SData/*8:0*/ __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*0:0*/ __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*5:0*/ __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT____Vcellout__sample_clk_en_sr__out;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT____Vcellout__sample_clk_en_sr__out = 0;
    IData/*29:0*/ __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__final_phase_p;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__final_phase_p = 0;
    IData/*17:0*/ __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__ws_post_opl_p;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__ws_post_opl_p = 0;
    CData/*4:0*/ __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    IData/*19:0*/ __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*0:0*/ __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*4:0*/ __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    IData/*19:0*/ __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*0:0*/ __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    IData/*23:0*/ __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__rand_num;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__rand_num = 0;
    CData/*2:0*/ __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT____Vcellout__sample_clk_en_sr__out;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT____Vcellout__sample_clk_en_sr__out = 0;
    SData/*8:0*/ __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__op_type_p;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__op_type_p = 0;
    CData/*2:0*/ __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__bank_num_p;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__bank_num_p = 0;
    SData/*14:0*/ __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__op_num_p;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__op_num_p = 0;
    CData/*4:0*/ __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    IData/*25:0*/ __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*0:0*/ __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*4:0*/ __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    IData/*25:0*/ __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*0:0*/ __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*4:0*/ __Vdlyvdim0__opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvdim0__opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    SData/*12:0*/ __Vdlyvval__opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvval__opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*0:0*/ __Vdlyvset__opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvset__opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*4:0*/ __Vdlyvdim0__opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvdim0__opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    SData/*12:0*/ __Vdlyvval__opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvval__opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*0:0*/ __Vdlyvset__opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    __Vdlyvset__opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0;
    CData/*7:0*/ __Vdly__opl3__DOT__genblk1__DOT__timers__DOT__timer1_inst__DOT__timer;
    __Vdly__opl3__DOT__genblk1__DOT__timers__DOT__timer1_inst__DOT__timer = 0;
    CData/*7:0*/ __Vdly__opl3__DOT__genblk1__DOT__timers__DOT__timer2_inst__DOT__timer;
    __Vdly__opl3__DOT__genblk1__DOT__timers__DOT__timer2_inst__DOT__timer = 0;
    VlWide<5>/*159:0*/ __Vtemp_3;
    VlWide<3>/*95:0*/ __Vtemp_27;
    // Body
    __Vdly__opl3__DOT__sample_clk_gen__DOT__counter 
        = vlSelf->opl3__DOT__sample_clk_gen__DOT__counter;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__tl_p 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__tl_p;
    __Vdlyvset__opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0U;
    __Vdlyvset__opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0U;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT____Vcellout__vib_sr__out 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT____Vcellout__vib_sr__out;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT____Vcellout__sample_clk_en_sr__out 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT____Vcellout__sample_clk_en_sr__out;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT____Vcellout__sample_clk_en_sr__out 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT____Vcellout__sample_clk_en_sr__out;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT____Vcellout__sample_clk_en_sr__out 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT____Vcellout__sample_clk_en_sr__out;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT____Vcellout__sample_clk_en_sr__out 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT____Vcellout__sample_clk_en_sr__out;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__op_type_p 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__op_type_p;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__final_phase_p 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__final_phase_p;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0U;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0U;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT__vibrato__DOT__vibrato_index_p1 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT__vibrato__DOT__vibrato_index_p1;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__ws_post_opl_p 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__ws_post_opl_p;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT____Vcellout__eg_reset_sr__out 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT____Vcellout__eg_reset_sr__out;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_state 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_state;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_timer 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_timer;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0U;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0U;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0U;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0U;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0U;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0U;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0U;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0U;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__op_num_p 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__op_num_p;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__op_num_p 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__op_num_p;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0U;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0U;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0U;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0U;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0U;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0U;
    __Vdlyvset__opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0U;
    __Vdlyvset__opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0U;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0U;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0U;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0U;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0U;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0U;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0U;
    __Vdly__opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__force_timer_overflow_sync__DOT__sync_regs 
        = vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__force_timer_overflow_sync__DOT__sync_regs;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0U;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0U;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0U;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0U;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0U;
    __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 0U;
    __Vdly__opl3__DOT__genblk1__DOT__timers__DOT__timer2_inst__DOT__timer 
        = vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer2_inst__DOT__timer;
    __Vdly__opl3__DOT__genblk1__DOT__timers__DOT__timer1_inst__DOT__timer 
        = vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer1_inst__DOT__timer;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__bank_num_p 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__bank_num_p;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__bank_num_p 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__bank_num_p;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_p 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_p;
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__rand_num 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__rand_num;
    __Vdly__opl3__DOT__sample_clk_gen__DOT__counter 
        = ((0x2a9U == (IData)(vlSelf->opl3__DOT__sample_clk_gen__DOT__counter))
            ? 0U : (0x3ffU & ((IData)(1U) + (IData)(vlSelf->opl3__DOT__sample_clk_gen__DOT__counter))));
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__tl_p 
        = (0x3ffffU & VL_SHIFTL_III(18,18,32, vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__tl_p, 6U));
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__tl_p 
        = ((0x3ffc0U & __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__tl_p) 
           | (0x3fU & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__ksl_tl_mem__dob)));
    VL_SHIFTL_WWI(130,130,32, __Vtemp_3, vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT____Vcellout__feedback_sr__out, 0x1aU);
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT____Vcellout__feedback_sr__out[0U] 
        = __Vtemp_3[0U];
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT____Vcellout__feedback_sr__out[1U] 
        = __Vtemp_3[1U];
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT____Vcellout__feedback_sr__out[2U] 
        = __Vtemp_3[2U];
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT____Vcellout__feedback_sr__out[3U] 
        = __Vtemp_3[3U];
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT____Vcellout__feedback_sr__out[4U] 
        = (3U & __Vtemp_3[4U]);
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT____Vcellout__feedback_sr__out[0U] 
        = ((0xfc000000U & vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT____Vcellout__feedback_sr__out[0U]) 
           | vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT____Vcellout__feedback_mem__dob);
    if ((IData)((0xc0000U == (0xc0000U & vlSelf->opl3__DOT__channels__DOT__operator_out)))) {
        vlSelf->opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_h1f1451d1__0 
            = (0x1fffU & vlSelf->opl3__DOT__channels__DOT__operator_out);
        if ((0x11U >= (0x1fU & (vlSelf->opl3__DOT__channels__DOT__operator_out 
                                >> 0xdU)))) {
            __Vdlyvval__opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = vlSelf->opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_h1f1451d1__0;
            __Vdlyvset__opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 1U;
            __Vdlyvdim0__opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = (0x1fU & (vlSelf->opl3__DOT__channels__DOT__operator_out 
                            >> 0xdU));
        }
    }
    if ((IData)((0x80000U == (0xc0000U & vlSelf->opl3__DOT__channels__DOT__operator_out)))) {
        vlSelf->opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_h1f1451d1__0 
            = (0x1fffU & vlSelf->opl3__DOT__channels__DOT__operator_out);
        if ((0x11U >= (0x1fU & (vlSelf->opl3__DOT__channels__DOT__operator_out 
                                >> 0xdU)))) {
            __Vdlyvval__opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = vlSelf->opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_h1f1451d1__0;
            __Vdlyvset__opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 1U;
            __Vdlyvdim0__opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = (0x1fU & (vlSelf->opl3__DOT__channels__DOT__operator_out 
                            >> 0xdU));
        }
    }
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT____Vcellout__vib_sr__out 
        = (3U & VL_SHIFTL_III(2,2,32, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT____Vcellout__vib_sr__out), 1U));
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT____Vcellout__vib_sr__out 
        = ((2U & (IData)(__Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT____Vcellout__vib_sr__out)) 
           | (1U & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__am_vib_egt_ksr_mult_mem__dob) 
                    >> 6U)));
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT____Vcellout__sample_clk_en_sr__out 
        = (7U & VL_SHIFTL_III(3,3,32, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT____Vcellout__sample_clk_en_sr__out), 1U));
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT____Vcellout__sample_clk_en_sr__out 
        = ((6U & (IData)(__Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT____Vcellout__sample_clk_en_sr__out)) 
           | (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_sample_clk_en));
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT____Vcellout__sample_clk_en_sr__out 
        = (7U & VL_SHIFTL_III(3,3,32, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT____Vcellout__sample_clk_en_sr__out), 1U));
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT____Vcellout__sample_clk_en_sr__out 
        = ((6U & (IData)(__Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT____Vcellout__sample_clk_en_sr__out)) 
           | (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_sample_clk_en));
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT____Vcellout__sample_clk_en_sr__out 
        = (0x3fU & VL_SHIFTL_III(6,6,32, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT____Vcellout__sample_clk_en_sr__out), 1U));
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT____Vcellout__sample_clk_en_sr__out 
        = ((0x3eU & (IData)(__Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT____Vcellout__sample_clk_en_sr__out)) 
           | (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_sample_clk_en));
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT____Vcellout__sample_clk_en_sr__out 
        = (0x3fU & VL_SHIFTL_III(6,6,32, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT____Vcellout__sample_clk_en_sr__out), 1U));
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT____Vcellout__sample_clk_en_sr__out 
        = ((0x3eU & (IData)(__Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT____Vcellout__sample_clk_en_sr__out)) 
           | (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_sample_clk_en));
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__op_type_p 
        = (0x1ffU & VL_SHIFTL_III(9,9,32, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__op_type_p), 3U));
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__op_type_p 
        = ((0x1f8U & (IData)(__Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__op_type_p)) 
           | (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__op_type_p0));
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__final_phase_p 
        = (0x3fffffffU & VL_SHIFTL_III(30,30,32, vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__final_phase_p, 0xaU));
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__final_phase_p 
        = ((0x3ffffc00U & __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__final_phase_p) 
           | (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__final_phase_p3));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__sample_clk_en_sr__out 
        = (0x3fU & VL_SHIFTL_III(6,6,32, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__sample_clk_en_sr__out), 1U));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__sample_clk_en_sr__out 
        = ((0x3eU & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__sample_clk_en_sr__out)) 
           | (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_sample_clk_en));
    if ((0x20U & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__bank_num_p) 
                  & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT____Vcellout__sample_clk_en_sr__out)))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_hbc745659__0 
            = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT____Vcellinp__feedback_mem__dia;
        if ((0x11U >= (0x1fU & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__op_num_p 
                                >> 0x19U)))) {
            __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_hbc745659__0;
            __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 1U;
            __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = (0x1fU & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__op_num_p 
                            >> 0x19U));
        }
    }
    if ((IData)(((~ ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__bank_num_p) 
                     >> 5U)) & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT____Vcellout__sample_clk_en_sr__out) 
                                >> 5U)))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_hbc745659__0 
            = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT____Vcellinp__feedback_mem__dia;
        if ((0x11U >= (0x1fU & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__op_num_p 
                                >> 0x19U)))) {
            __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_hbc745659__0;
            __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 1U;
            __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = (0x1fU & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__op_num_p 
                            >> 0x19U));
        }
    }
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT____Vcellout__sample_clk_en_sr__out 
        = (7U & VL_SHIFTL_III(3,3,32, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT____Vcellout__sample_clk_en_sr__out), 1U));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT____Vcellout__sample_clk_en_sr__out 
        = ((6U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT____Vcellout__sample_clk_en_sr__out)) 
           | (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_sample_clk_en));
    if (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_sample_clk_en) {
        __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT__vibrato__DOT__vibrato_index_p1 
            = (0x1fffU & ((IData)(1U) + (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT__vibrato__DOT__vibrato_index_p1)));
    }
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__ws_post_opl_p 
        = (0x3ffffU & VL_SHIFTL_III(18,18,32, vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__ws_post_opl_p, 3U));
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__ws_post_opl_p 
        = ((0x3fff8U & __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__ws_post_opl_p) 
           | (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__ws_post_opl_p0));
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT____Vcellout__eg_reset_sr__out 
        = (7U & VL_SHIFTL_III(3,3,32, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT____Vcellout__eg_reset_sr__out), 1U));
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT____Vcellout__eg_reset_sr__out 
        = ((6U & (IData)(__Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT____Vcellout__eg_reset_sr__out)) 
           | (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__eg_reset_p0));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__sl_p 
        = (0xfffU & VL_SHIFTL_III(12,12,32, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__sl_p), 4U));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__sl_p 
        = ((0xff0U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__sl_p)) 
           | (0xfU & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__sl_rr_mem__dob) 
                      >> 4U)));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT____Vcellout__key_on_sr__out 
        = (7U & VL_SHIFTL_III(3,3,32, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT____Vcellout__key_on_sr__out), 1U));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT____Vcellout__key_on_sr__out 
        = ((6U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT____Vcellout__key_on_sr__out)) 
           | (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__key_on_p0));
    if (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT____Vcellinp__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__wea) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_hb6d43ef3__0 
            = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_new_p3;
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_hb6861da5__0 
            = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_p3;
        if ((0x11U >= (0x1fU & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__op_num_p) 
                                >> 0xaU)))) {
            __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_hb6d43ef3__0;
            __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 1U;
            __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = (0x1fU & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__op_num_p) 
                            >> 0xaU));
            __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_hb6861da5__0;
            __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 1U;
            __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = (0x1fU & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__op_num_p) 
                            >> 0xaU));
        }
    }
    if (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT____Vcellinp__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__wea) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_hb6d43ef3__0 
            = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_new_p3;
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_hb6861da5__0 
            = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_p3;
        if ((0x11U >= (0x1fU & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__op_num_p) 
                                >> 0xaU)))) {
            __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_hb6d43ef3__0;
            __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 1U;
            __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = (0x1fU & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__op_num_p) 
                            >> 0xaU));
            __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_hb6861da5__0;
            __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 1U;
            __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = (0x1fU & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__op_num_p) 
                            >> 0xaU));
        }
    }
    if ((4U & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__bank_num_p) 
               & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT____Vcellout__sample_clk_en_sr__out)))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_hbe76e32b__0 
            = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_p3;
        if ((0x11U >= (0x1fU & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__op_num_p 
                                >> 0xaU)))) {
            __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_hbe76e32b__0;
            __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 1U;
            __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = (0x1fU & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__op_num_p 
                            >> 0xaU));
        }
    }
    if ((1U & ((~ ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__bank_num_p) 
                   >> 2U)) & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT____Vcellout__sample_clk_en_sr__out) 
                              >> 2U)))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_hbe76e32b__0 
            = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_p3;
        if ((0x11U >= (0x1fU & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__op_num_p 
                                >> 0xaU)))) {
            __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_hbe76e32b__0;
            __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 1U;
            __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = (0x1fU & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__op_num_p 
                            >> 0xaU));
        }
    }
    if ((1U & ((1U == vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__state)
                ? ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__self) 
                   >> 5U) : (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT____Vcellinp__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__wea)))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_hecc6a027__0 
            = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT____Vcellinp__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__dia;
        if ((8U >= (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT____Vcellinp__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__addra))) {
            __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_hecc6a027__0;
            __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 1U;
            __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT____Vcellinp__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__addra;
        }
    }
    if ((1U & ((1U == vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__state)
                ? (~ ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__self) 
                      >> 5U)) : (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT____Vcellinp__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__wea)))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_hecc6a027__0 
            = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT____Vcellinp__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__dia;
        if ((8U >= (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT____Vcellinp__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__addra))) {
            __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_hecc6a027__0;
            __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 1U;
            __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT____Vcellinp__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__addra;
        }
    }
    vlSelf->opl3__DOT__channels__DOT__operator_out_mem__DOT__bankb_p 
        = (3U & VL_SHIFTL_III(2,2,32, (IData)(vlSelf->opl3__DOT__channels__DOT__operator_out_mem__DOT__bankb_p), 1U));
    vlSelf->opl3__DOT__channels__DOT__operator_out_mem__DOT__bankb_p 
        = ((2U & (IData)(vlSelf->opl3__DOT__channels__DOT__operator_out_mem__DOT__bankb_p)) 
           | (1U & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                    >> 0x11U)));
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__op_num_p 
        = (0x7fffU & VL_SHIFTL_III(15,15,32, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__op_num_p), 5U));
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__op_num_p 
        = ((0x7fe0U & (IData)(__Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__op_num_p)) 
           | (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num));
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__op_num_p 
        = (0x7fffU & VL_SHIFTL_III(15,15,32, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__op_num_p), 5U));
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__op_num_p 
        = ((0x7fe0U & (IData)(__Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__op_num_p)) 
           | (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__op_num_p 
        = (0x3fffffffU & VL_SHIFTL_III(30,30,32, vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__op_num_p, 5U));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__op_num_p 
        = ((0x3fffffe0U & vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__op_num_p) 
           | (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__op_num_p 
        = (0x3fffffffU & VL_SHIFTL_III(30,30,32, vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__op_num_p, 5U));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__op_num_p 
        = ((0x3fffffe0U & vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__op_num_p) 
           | (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__op_num_p 
        = (0x7fffU & VL_SHIFTL_III(15,15,32, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__op_num_p), 5U));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__op_num_p 
        = ((0x7fe0U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__op_num_p)) 
           | (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p 
        = (0x3fffffffU & VL_SHIFTL_III(30,30,32, vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p, 5U));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p 
        = ((0x3fffffe0U & vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p) 
           | (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num));
    if (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT____Vcellinp__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__wea) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_hecc6a027__0 
            = (1U & vlSelf->opl3__DOT__opl3_reg_wr);
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_h95153f4e__0 
            = (0xfU & vlSelf->opl3__DOT__opl3_reg_wr);
        vlSelf->opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_h86a57974__0 
            = (0xffU & vlSelf->opl3__DOT__opl3_reg_wr);
        if ((8U >= (0xfU & (vlSelf->opl3__DOT__opl3_reg_wr 
                            >> 8U)))) {
            __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_hecc6a027__0;
            __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 1U;
            __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = (0xfU & (vlSelf->opl3__DOT__opl3_reg_wr 
                           >> 8U));
            __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_h95153f4e__0;
            __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 1U;
            __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = (0xfU & (vlSelf->opl3__DOT__opl3_reg_wr 
                           >> 8U));
            __Vdlyvval__opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = vlSelf->opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_h86a57974__0;
            __Vdlyvset__opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 1U;
            __Vdlyvdim0__opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = (0xfU & (vlSelf->opl3__DOT__opl3_reg_wr 
                           >> 8U));
        }
    }
    if (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT____Vcellinp__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__wea) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_hecc6a027__0 
            = (1U & vlSelf->opl3__DOT__opl3_reg_wr);
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_h95153f4e__0 
            = (0xfU & vlSelf->opl3__DOT__opl3_reg_wr);
        vlSelf->opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_h86a57974__0 
            = (0xffU & vlSelf->opl3__DOT__opl3_reg_wr);
        if ((8U >= (0xfU & (vlSelf->opl3__DOT__opl3_reg_wr 
                            >> 8U)))) {
            __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_hecc6a027__0;
            __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 1U;
            __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = (0xfU & (vlSelf->opl3__DOT__opl3_reg_wr 
                           >> 8U));
            __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_h95153f4e__0;
            __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 1U;
            __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = (0xfU & (vlSelf->opl3__DOT__opl3_reg_wr 
                           >> 8U));
            __Vdlyvval__opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = vlSelf->opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_h86a57974__0;
            __Vdlyvset__opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 1U;
            __Vdlyvdim0__opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = (0xfU & (vlSelf->opl3__DOT__opl3_reg_wr 
                           >> 8U));
        }
    }
    if (((vlSelf->opl3__DOT__opl3_reg_wr >> 0x10U) 
         & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellinp__ksl_tl_mem__wea))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_h78e36339__0 
            = (0xffU & vlSelf->opl3__DOT__opl3_reg_wr);
        if ((0x15U >= (0x1fU & (vlSelf->opl3__DOT__opl3_reg_wr 
                                >> 8U)))) {
            __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_h78e36339__0;
            __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 1U;
            __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = (0x1fU & (vlSelf->opl3__DOT__opl3_reg_wr 
                            >> 8U));
        }
    }
    if (((~ (vlSelf->opl3__DOT__opl3_reg_wr >> 0x10U)) 
         & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellinp__ksl_tl_mem__wea))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_h78e36339__0 
            = (0xffU & vlSelf->opl3__DOT__opl3_reg_wr);
        if ((0x15U >= (0x1fU & (vlSelf->opl3__DOT__opl3_reg_wr 
                                >> 8U)))) {
            __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_h78e36339__0;
            __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 1U;
            __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = (0x1fU & (vlSelf->opl3__DOT__opl3_reg_wr 
                            >> 8U));
        }
    }
    if (((vlSelf->opl3__DOT__opl3_reg_wr >> 0x10U) 
         & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellinp__ws_mem__wea))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_hebd03cde__0 
            = (7U & vlSelf->opl3__DOT__opl3_reg_wr);
        if ((0x15U >= (0x1fU & (vlSelf->opl3__DOT__opl3_reg_wr 
                                >> 8U)))) {
            __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_hebd03cde__0;
            __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 1U;
            __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = (0x1fU & (vlSelf->opl3__DOT__opl3_reg_wr 
                            >> 8U));
        }
    }
    if (((~ (vlSelf->opl3__DOT__opl3_reg_wr >> 0x10U)) 
         & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellinp__ws_mem__wea))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_hebd03cde__0 
            = (7U & vlSelf->opl3__DOT__opl3_reg_wr);
        if ((0x15U >= (0x1fU & (vlSelf->opl3__DOT__opl3_reg_wr 
                                >> 8U)))) {
            __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_hebd03cde__0;
            __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 1U;
            __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = (0x1fU & (vlSelf->opl3__DOT__opl3_reg_wr 
                            >> 8U));
        }
    }
    if (((vlSelf->opl3__DOT__opl3_reg_wr >> 0x10U) 
         & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellinp__sl_rr_mem__wea))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_h78e36339__0 
            = (0xffU & vlSelf->opl3__DOT__opl3_reg_wr);
        if ((0x15U >= (0x1fU & (vlSelf->opl3__DOT__opl3_reg_wr 
                                >> 8U)))) {
            __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_h78e36339__0;
            __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 1U;
            __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = (0x1fU & (vlSelf->opl3__DOT__opl3_reg_wr 
                            >> 8U));
        }
    }
    if (((~ (vlSelf->opl3__DOT__opl3_reg_wr >> 0x10U)) 
         & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellinp__sl_rr_mem__wea))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_h78e36339__0 
            = (0xffU & vlSelf->opl3__DOT__opl3_reg_wr);
        if ((0x15U >= (0x1fU & (vlSelf->opl3__DOT__opl3_reg_wr 
                                >> 8U)))) {
            __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_h78e36339__0;
            __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 1U;
            __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = (0x1fU & (vlSelf->opl3__DOT__opl3_reg_wr 
                            >> 8U));
        }
    }
    if (((vlSelf->opl3__DOT__opl3_reg_wr >> 0x10U) 
         & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellinp__ar_dr_mem__wea))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_h78e36339__0 
            = (0xffU & vlSelf->opl3__DOT__opl3_reg_wr);
        if ((0x15U >= (0x1fU & (vlSelf->opl3__DOT__opl3_reg_wr 
                                >> 8U)))) {
            __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_h78e36339__0;
            __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 1U;
            __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = (0x1fU & (vlSelf->opl3__DOT__opl3_reg_wr 
                            >> 8U));
        }
    }
    if (((~ (vlSelf->opl3__DOT__opl3_reg_wr >> 0x10U)) 
         & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellinp__ar_dr_mem__wea))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_h78e36339__0 
            = (0xffU & vlSelf->opl3__DOT__opl3_reg_wr);
        if ((0x15U >= (0x1fU & (vlSelf->opl3__DOT__opl3_reg_wr 
                                >> 8U)))) {
            __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_h78e36339__0;
            __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 1U;
            __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = (0x1fU & (vlSelf->opl3__DOT__opl3_reg_wr 
                            >> 8U));
        }
    }
    __Vdly__opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__force_timer_overflow_sync__DOT__sync_regs 
        = ((2U & ((IData)(vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__force_timer_overflow_sync__DOT__sync_regs) 
                  << 1U)) | (IData)(vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__host_force_timer_overflow));
    if (((vlSelf->opl3__DOT__opl3_reg_wr >> 0x10U) 
         & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellinp__fnum_low_mem__wea))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_h86a57974__0 
            = (0xffU & vlSelf->opl3__DOT__opl3_reg_wr);
        if ((8U >= (0xfU & (vlSelf->opl3__DOT__opl3_reg_wr 
                            >> 8U)))) {
            __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_h86a57974__0;
            __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 1U;
            __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = (0xfU & (vlSelf->opl3__DOT__opl3_reg_wr 
                           >> 8U));
        }
    }
    if (((~ (vlSelf->opl3__DOT__opl3_reg_wr >> 0x10U)) 
         & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellinp__fnum_low_mem__wea))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_h86a57974__0 
            = (0xffU & vlSelf->opl3__DOT__opl3_reg_wr);
        if ((8U >= (0xfU & (vlSelf->opl3__DOT__opl3_reg_wr 
                            >> 8U)))) {
            __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_h86a57974__0;
            __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 1U;
            __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = (0xfU & (vlSelf->opl3__DOT__opl3_reg_wr 
                           >> 8U));
        }
    }
    if (((vlSelf->opl3__DOT__opl3_reg_wr >> 0x10U) 
         & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellinp__am_vib_egt_ksr_mult_mem__wea))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_h78e36339__0 
            = (0xffU & vlSelf->opl3__DOT__opl3_reg_wr);
        if ((0x15U >= (0x1fU & (vlSelf->opl3__DOT__opl3_reg_wr 
                                >> 8U)))) {
            __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_h78e36339__0;
            __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 1U;
            __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = (0x1fU & (vlSelf->opl3__DOT__opl3_reg_wr 
                            >> 8U));
        }
    }
    if (((~ (vlSelf->opl3__DOT__opl3_reg_wr >> 0x10U)) 
         & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellinp__am_vib_egt_ksr_mult_mem__wea))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_h78e36339__0 
            = (0xffU & vlSelf->opl3__DOT__opl3_reg_wr);
        if ((0x15U >= (0x1fU & (vlSelf->opl3__DOT__opl3_reg_wr 
                                >> 8U)))) {
            __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_h78e36339__0;
            __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 1U;
            __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = (0x1fU & (vlSelf->opl3__DOT__opl3_reg_wr 
                            >> 8U));
        }
    }
    if (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT____Vcellinp__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__wea) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_hf28499db__0 
            = (0x1fU & vlSelf->opl3__DOT__opl3_reg_wr);
        if ((8U >= (0xfU & (vlSelf->opl3__DOT__opl3_reg_wr 
                            >> 8U)))) {
            __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_hf28499db__0;
            __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 1U;
            __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = (0xfU & (vlSelf->opl3__DOT__opl3_reg_wr 
                           >> 8U));
        }
    }
    if (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT____Vcellinp__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__wea) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_hf28499db__0 
            = (0x1fU & vlSelf->opl3__DOT__opl3_reg_wr);
        if ((8U >= (0xfU & (vlSelf->opl3__DOT__opl3_reg_wr 
                            >> 8U)))) {
            __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT____Vlvbound_hf28499db__0;
            __Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 = 1U;
            __Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0 
                = (0xfU & (vlSelf->opl3__DOT__opl3_reg_wr 
                           >> 8U));
        }
    }
    if (vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer2_inst__DOT__start_timer_set_pulse) {
        __Vdly__opl3__DOT__genblk1__DOT__timers__DOT__timer2_inst__DOT__timer 
            = vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer2;
    } else if (vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer2_inst__DOT__tick_pulse) {
        __Vdly__opl3__DOT__genblk1__DOT__timers__DOT__timer2_inst__DOT__timer 
            = (0xffU & ((0xffU == (IData)(vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer2_inst__DOT__timer))
                         ? (IData)(vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer2)
                         : ((IData)(1U) + (IData)(vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer2_inst__DOT__timer))));
    }
    if (vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer1_inst__DOT__start_timer_set_pulse) {
        __Vdly__opl3__DOT__genblk1__DOT__timers__DOT__timer1_inst__DOT__timer 
            = vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer1;
    } else if (vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer1_inst__DOT__tick_pulse) {
        __Vdly__opl3__DOT__genblk1__DOT__timers__DOT__timer1_inst__DOT__timer 
            = (0xffU & ((0xffU == (IData)(vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer1_inst__DOT__timer))
                         ? (IData)(vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer1)
                         : ((IData)(1U) + (IData)(vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer1_inst__DOT__timer))));
    }
    if (vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__st2) {
        vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer2_inst__DOT__tick_counter 
            = (((IData)(vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer2_inst__DOT__tick_pulse) 
                | (IData)(vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer2_inst__DOT__start_timer_set_pulse))
                ? 0U : (0x3fffU & ((IData)(1U) + (IData)(vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer2_inst__DOT__tick_counter))));
    }
    if (vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__st1) {
        vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer1_inst__DOT__tick_counter 
            = (((IData)(vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer1_inst__DOT__tick_pulse) 
                | (IData)(vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer1_inst__DOT__start_timer_set_pulse))
                ? 0U : (0xfffU & ((IData)(1U) + (IData)(vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer1_inst__DOT__tick_counter))));
    }
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__bank_num_p 
        = (7U & VL_SHIFTL_III(3,3,32, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__bank_num_p), 1U));
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__bank_num_p 
        = ((6U & (IData)(__Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__bank_num_p)) 
           | (0x12U < (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state)));
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__bank_num_p 
        = (7U & VL_SHIFTL_III(3,3,32, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__bank_num_p), 1U));
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__bank_num_p 
        = ((6U & (IData)(__Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__bank_num_p)) 
           | (0x12U < (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state)));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__bank_num_p 
        = (0x3fU & VL_SHIFTL_III(6,6,32, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__bank_num_p), 1U));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__bank_num_p 
        = ((0x3eU & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__bank_num_p)) 
           | (0x12U < (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state)));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__bank_num_p 
        = (0x3fU & VL_SHIFTL_III(6,6,32, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__bank_num_p), 1U));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__bank_num_p 
        = ((0x3eU & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__bank_num_p)) 
           | (0x12U < (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state)));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__bank_num_p 
        = (0x3fU & VL_SHIFTL_III(6,6,32, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__bank_num_p), 1U));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__bank_num_p 
        = ((0x3eU & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__bank_num_p)) 
           | (0x12U < (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state)));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__bank_num_p 
        = (7U & VL_SHIFTL_III(3,3,32, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__bank_num_p), 1U));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__bank_num_p 
        = ((6U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__bank_num_p)) 
           | (0x12U < (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state)));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankb_p 
        = (3U & VL_SHIFTL_III(2,2,32, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankb_p), 1U));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankb_p 
        = ((2U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankb_p)) 
           | (0x12U < (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state)));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankb_p 
        = (3U & VL_SHIFTL_III(2,2,32, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankb_p), 1U));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankb_p 
        = ((2U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankb_p)) 
           | (0x12U < (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state)));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankb_p 
        = (3U & VL_SHIFTL_III(2,2,32, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankb_p), 1U));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankb_p 
        = ((2U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankb_p)) 
           | (0x12U < (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state)));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankb_p 
        = (3U & VL_SHIFTL_III(2,2,32, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankb_p), 1U));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankb_p 
        = ((2U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankb_p)) 
           | (0x12U < (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state)));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__delay_counter 
        = (((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__next_state) 
            != (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state))
            ? 0U : ((1U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__delay_counter))
                     ? 0U : (3U & ((IData)(1U) + (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__delay_counter)))));
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_p 
        = (0x7ffffffU & VL_SHIFTL_III(27,27,32, vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_p, 9U));
    __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_p 
        = ((0x7fffe00U & __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_p) 
           | vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__dob_array
           [(0x12U < (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state))]);
    if ((((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_sample_clk_en) 
          & (0x12U >= (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state))) 
         & (0U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num)))) {
        __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__rand_num 
            = (0xffffffU & ((0U != (1U & vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__rand_num))
                             ? (0x400181U ^ (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__rand_num 
                                             >> 1U))
                             : VL_SHIFTR_III(24,24,32, vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__rand_num, 1U)));
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__tremolo__DOT__tremolo_index_p1 
            = ((0x33ffU == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__tremolo__DOT__tremolo_index_p1))
                ? 0U : (0x3fffU & ((IData)(1U) + (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__tremolo__DOT__tremolo_index_p1))));
    }
    VL_SHIFTL_WWI(65,65,32, __Vtemp_27, vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__modulation_p, 0xdU);
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__modulation_p[0U] 
        = __Vtemp_27[0U];
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__modulation_p[1U] 
        = __Vtemp_27[1U];
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__modulation_p[2U] 
        = (1U & __Vtemp_27[2U]);
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__modulation_p[0U] 
        = ((0xffffe000U & vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__modulation_p[0U]) 
           | ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__use_feedback_p1)
               ? (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_result_p1)
               : (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__modulation_p1)));
    vlSelf->irq_n = (1U & (~ (IData)(vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__irq)));
    vlSelf->opl3__DOT__channels__DOT__ops_done_pulse 
        = (IData)((0xe2000U == (0xfe000U & vlSelf->opl3__DOT__channels__DOT__operator_out)));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT__vibrato__DOT__fnum_p1 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fnum;
    __Vtableidx4 = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__theta_p3;
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__log_sin_out_p4 
        = Vopl3__ConstPool__TABLE_h94f3441f_0[__Vtableidx4];
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__ksl_add_rom__DOT__tmp0_p1 
        = (0x3fU & ((7U & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__block_fnum_high_mem__dob) 
                           >> 2U)) - (IData)(8U)));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__rate_p1 
        = (0x7fU & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__ks_p0) 
                    + (0x3fU & VL_SHIFTL_III(6,6,32, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__requested_rate_p0), 2U))));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__rate_hi_p2 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__rate_hi_p1;
    vlSelf->opl3__DOT__channels__DOT__dac_prep__DOT__sample_valid_opl3_p1 
        = vlSelf->opl3__DOT__channels__DOT__channel_valid;
    __Vtableidx3 = ((0xcU & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__block_fnum_high_mem__dob) 
                             << 2U)) | (3U & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fnum_low_mem__dob) 
                                              >> 6U)));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__ksl_add_rom__DOT__rom_out_p1 
        = Vopl3__ConstPool__TABLE_he3797a36_0[__Vtableidx3];
    if ((IData)(((((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT____Vcellout__sample_clk_en_sr__out) 
                   >> 1U) & (~ ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__bank_num_p) 
                                >> 1U))) & (0x220U 
                                            == (0x3e0U 
                                                & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__op_num_p)))))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__tc_phase_friend 
            = (0x3ffU & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_p2 
                         >> 9U));
    }
    if ((IData)(((((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT____Vcellout__sample_clk_en_sr__out) 
                   >> 1U) & (~ ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__bank_num_p) 
                                >> 1U))) & (0x1a0U 
                                            == (0x3e0U 
                                                & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__op_num_p)))))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__hh_phase_friend 
            = (0x3ffU & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_p2 
                         >> 9U));
    }
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_p2 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_p1;
    if ((IData)(((((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT____Vcellout__sample_clk_en_sr__out) 
                   & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__bank_num_p)) 
                  >> 2U) & (0x4400U == (0x7c00U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__op_num_p)))))) {
        if (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_state) {
            if (((((((((0U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_timer)) 
                       | (0x1000U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_timer))) 
                      | (0x800U == (0xfffU & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_timer)))) 
                     | (0x400U == (0x7ffU & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_timer)))) 
                    | (0x200U == (0x3ffU & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_timer)))) 
                   | (0x100U == (0x1ffU & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_timer)))) 
                  | (0x80U == (0xffU & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_timer)))) 
                 | (0x40U == (0x7fU & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_timer))))) {
                vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_add 
                    = ((0U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_timer))
                        ? 0U : ((0x1000U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_timer))
                                 ? 0xdU : ((0x800U 
                                            == (0xfffU 
                                                & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_timer)))
                                            ? 0xcU : 
                                           ((0x400U 
                                             == (0x7ffU 
                                                 & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_timer)))
                                             ? 0xbU
                                             : ((0x200U 
                                                 == 
                                                 (0x3ffU 
                                                  & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_timer)))
                                                 ? 0xaU
                                                 : 
                                                ((0x100U 
                                                  == 
                                                  (0x1ffU 
                                                   & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_timer)))
                                                  ? 9U
                                                  : 
                                                 ((0x80U 
                                                   == 
                                                   (0xffU 
                                                    & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_timer)))
                                                   ? 8U
                                                   : 7U)))))));
            } else if ((0x20U == (0x3fU & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_timer)))) {
                vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_add = 6U;
            } else if ((0x10U == (0x1fU & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_timer)))) {
                vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_add = 5U;
            } else if ((8U == (0xfU & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_timer)))) {
                vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_add = 4U;
            } else if ((4U == (7U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_timer)))) {
                vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_add = 3U;
            } else if ((2U == (3U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_timer)))) {
                vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_add = 2U;
            } else if ((1U == (1U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_timer)))) {
                vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_add = 1U;
            }
            __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_timer 
                = (0x1fffU & ((IData)(1U) + (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_timer)));
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_timer_lo 
                = (3U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_timer));
        }
        __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_state 
            = (1U & (~ (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_state)));
    }
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_shift_p2 = 0U;
    if (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__requested_rate_not_zero_p1) {
        if ((0xcU > (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__rate_hi_p1))) {
            if (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_state) {
                if ((0xcU == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_shift_p1))) {
                    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_shift_p2 = 1U;
                } else if ((0xdU == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_shift_p1))) {
                    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_shift_p2 
                        = (1U & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__rate_lo_p1) 
                                 >> 1U));
                } else if ((0xeU == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_shift_p1))) {
                    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_shift_p2 
                        = (1U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__rate_lo_p1));
                }
            }
        } else {
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_shift_p2 
                = (3U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__env_shift_pre_p1));
            if ((4U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__env_shift_pre_p1))) {
                vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_shift_p2 = 3U;
            }
            if ((0U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__env_shift_pre_p1))) {
                vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_shift_p2 
                    = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_state;
            }
        }
    }
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__modulation_out_p1 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__out_p6;
    vlSelf->opl3__DOT__channels__DOT__dac_prep__DOT__sample_opl3_r_p1 
        = (0xffffffU & VL_SHIFTL_III(24,24,32, VL_EXTENDS_II(24,16, (IData)(vlSelf->opl3__DOT__channels__DOT__channel_r)), 5U));
    vlSelf->opl3__DOT__channels__DOT__dac_prep__DOT__sample_opl3_l_p1 
        = (0xffffffU & VL_SHIFTL_III(24,24,32, VL_EXTENDS_II(24,16, (IData)(vlSelf->opl3__DOT__channels__DOT__channel_l)), 5U));
    if ((1U & ((vlSelf->opl3__DOT__channels__DOT__self[1U] 
                >> 0x11U) & (vlSelf->opl3__DOT__channels__DOT__signals 
                             >> 0x18U)))) {
        vlSelf->opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__genblk1__DOT__dob_p1 
            = ((0x11U >= (0x1fU & (vlSelf->opl3__DOT__channels__DOT__signals 
                                   >> 0x19U))) ? vlSelf->opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram
               [(0x1fU & (vlSelf->opl3__DOT__channels__DOT__signals 
                          >> 0x19U))] : 0U);
    }
    if ((1U & ((~ (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                   >> 0x11U)) & (vlSelf->opl3__DOT__channels__DOT__signals 
                                 >> 0x18U)))) {
        vlSelf->opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__genblk1__DOT__dob_p1 
            = ((0x11U >= (0x1fU & (vlSelf->opl3__DOT__channels__DOT__signals 
                                   >> 0x19U))) ? vlSelf->opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram
               [(0x1fU & (vlSelf->opl3__DOT__channels__DOT__signals 
                          >> 0x19U))] : 0U);
    }
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p1 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num;
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__genblk1__DOT__genblk1__DOT__dob_p2 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__genblk1__DOT__dob_p1;
    if (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__reb_mem) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__genblk1__DOT__dob_p1 
            = ((8U >= (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__cnt1_channel_mem_rd_address)) 
               && vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram
               [vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__cnt1_channel_mem_rd_address]);
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__genblk1__DOT__dob_p1 
            = ((8U >= (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_channel_mem_rd_address))
                ? vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram
               [vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_channel_mem_rd_address]
                : 0U);
        if ((0x11U >= (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num))) {
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__genblk1__DOT__dob_p1 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram
                [vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num];
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__genblk1__DOT__dob_p1 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram
                [vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num];
        } else {
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__genblk1__DOT__dob_p1 = 0U;
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__genblk1__DOT__dob_p1 = 0U;
        }
    }
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__genblk1__DOT__genblk1__DOT__dob_p2 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__genblk1__DOT__dob_p1;
    if (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__reb_mem) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__genblk1__DOT__dob_p1 
            = ((8U >= (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__cnt1_channel_mem_rd_address)) 
               && vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram
               [vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__cnt1_channel_mem_rd_address]);
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__genblk1__DOT__dob_p1 
            = ((8U >= (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_channel_mem_rd_address))
                ? vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram
               [vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_channel_mem_rd_address]
                : 0U);
        if ((0x11U >= (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num))) {
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__genblk1__DOT__dob_p1 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram
                [vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num];
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__genblk1__DOT__dob_p1 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram
                [vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num];
        } else {
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__genblk1__DOT__dob_p1 = 0U;
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__genblk1__DOT__dob_p1 = 0U;
        }
    }
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT__vibrato__DOT__dvb_p1 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__dvb;
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ryt_p1 
        = vlSelf->opl3__DOT__channels__DOT__ryt;
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__env_shifted_p4 
        = (0x3fffU & VL_SHIFTL_III(14,14,32, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__env_p3), 3U));
    vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer2_inst__DOT__start_timer_edge_detect__DOT__in_r0 
        = vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__st2;
    vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer1_inst__DOT__start_timer_edge_detect__DOT__in_r0 
        = vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__st1;
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__connection_sel_p1 
        = vlSelf->opl3__DOT__channels__DOT__connection_sel;
    if (((IData)(vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer2_overflow_pulse) 
         & (~ (IData)(vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__mt2)))) {
        vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__ft2 = 1U;
    }
    if ((1U & (((IData)(vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer1_overflow_pulse) 
                | ((IData)(vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__force_timer_overflow_sync__DOT__sync_regs) 
                   >> 1U)) & (~ (IData)(vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__mt1))))) {
        vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__ft1 = 1U;
    }
    if ((((IData)(vlSelf->opl3__DOT__reset_sync__DOT__r2) 
          | (IData)(vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__irq_rst)) 
         | (IData)(vlSelf->force_clear_flags))) {
        vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__ft2 = 0U;
        vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__ft1 = 0U;
    }
    if ((IData)((0x2b000U == (0x3ff00U & vlSelf->opl3__DOT__opl3_reg_wr)))) {
        vlSelf->led = ((0xeU & (IData)(vlSelf->led)) 
                       | (1U & (vlSelf->opl3__DOT__opl3_reg_wr 
                                >> 5U)));
    }
    if ((IData)((0x2b100U == (0x3ff00U & vlSelf->opl3__DOT__opl3_reg_wr)))) {
        vlSelf->led = ((0xdU & (IData)(vlSelf->led)) 
                       | (2U & (vlSelf->opl3__DOT__opl3_reg_wr 
                                >> 4U)));
    }
    if ((IData)((0x2b200U == (0x3ff00U & vlSelf->opl3__DOT__opl3_reg_wr)))) {
        vlSelf->led = ((0xbU & (IData)(vlSelf->led)) 
                       | (4U & (vlSelf->opl3__DOT__opl3_reg_wr 
                                >> 3U)));
    }
    if ((IData)((0x2b300U == (0x3ff00U & vlSelf->opl3__DOT__opl3_reg_wr)))) {
        vlSelf->led = ((7U & (IData)(vlSelf->led)) 
                       | (8U & (vlSelf->opl3__DOT__opl3_reg_wr 
                                >> 2U)));
    }
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__bank_num_p1 
        = (0x12U < (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT____Vcellout__sample_clk_en_sr__out 
        = __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT____Vcellout__sample_clk_en_sr__out;
    if (__Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram[__Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0] 
            = __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    }
    if (__Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram[__Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0] 
            = __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    }
    if (__Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram[__Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0] 
            = __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    }
    if (__Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram[__Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0] 
            = __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    }
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT____Vcellout__sample_clk_en_sr__out 
        = __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT____Vcellout__sample_clk_en_sr__out;
    if (__Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram[__Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0] 
            = __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    }
    if (__Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram[__Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0] 
            = __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    }
    if (__Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram[__Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0] 
            = __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    }
    if (__Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram[__Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0] 
            = __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    }
    if (__Vdlyvset__opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0) {
        vlSelf->opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram[__Vdlyvdim0__opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0] 
            = __Vdlyvval__opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    }
    if (__Vdlyvset__opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0) {
        vlSelf->opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram[__Vdlyvdim0__opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0] 
            = __Vdlyvval__opl3__DOT__channels__DOT__ch_abcd_cnt_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    }
    if (__Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram[__Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0] 
            = __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    }
    if (__Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram[__Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0] 
            = __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    }
    if (__Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram[__Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0] 
            = __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    }
    if (__Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram[__Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0] 
            = __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    }
    if (__Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram[__Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0] 
            = __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    }
    if (__Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram[__Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0] 
            = __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    }
    if (__Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram[__Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0] 
            = __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    }
    if (__Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram[__Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0] 
            = __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    }
    if (__Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram[__Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0] 
            = __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    }
    if (__Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram[__Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0] 
            = __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    }
    if (__Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram[__Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0] 
            = __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    }
    if (__Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram[__Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0] 
            = __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    }
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT____Vcellout__sample_clk_en_sr__out 
        = __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT____Vcellout__sample_clk_en_sr__out;
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__bank_num_p 
        = __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__bank_num_p;
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__op_num_p 
        = __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__op_num_p;
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__rhythm_phase_p3 
        = (0x3ffU & ((2U == (7U & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__op_type_p) 
                                   >> 3U))) ? (VL_SHIFTL_III(10,32,32, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__rm_xor_p2), 9U) 
                                               | ((1U 
                                                   & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__rm_xor_p2) 
                                                      ^ vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__rand_num))
                                                   ? 0xd0U
                                                   : 0x34U))
                      : ((4U == (7U & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__op_type_p) 
                                       >> 3U))) ? (
                                                   VL_SHIFTL_III(10,10,32, 
                                                                 (1U 
                                                                  & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__hh_phase_p2) 
                                                                     >> 8U)), 9U) 
                                                   | VL_SHIFTL_III(10,10,32, 
                                                                   ((1U 
                                                                     & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__hh_phase_p2) 
                                                                        >> 8U)) 
                                                                    ^ 
                                                                    (1U 
                                                                     & vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__rand_num)), 8U))
                          : ((5U == (7U & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__op_type_p) 
                                           >> 3U)))
                              ? (0x80U | VL_SHIFTL_III(10,32,32, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__rm_xor_p2), 9U))
                              : (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_p2 
                                 >> 9U)))));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__rand_num 
        = __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__rand_num;
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__op_type_p 
        = __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__op_type_p;
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT____Vcellout__sample_clk_en_sr__out 
        = __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT____Vcellout__sample_clk_en_sr__out;
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__bank_num_p 
        = __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__bank_num_p;
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__op_num_p 
        = __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__op_num_p;
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_timer 
        = __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_timer;
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_state 
        = __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_state;
    if (__Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram[__Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0] 
            = __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    }
    if (__Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram[__Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0] 
            = __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    }
    if (__Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram[__Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0] 
            = __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    }
    if (__Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram[__Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0] 
            = __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    }
    if (__Vdlyvset__opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0) {
        vlSelf->opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram[__Vdlyvdim0__opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0] 
            = __Vdlyvval__opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    }
    if (__Vdlyvset__opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0) {
        vlSelf->opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram[__Vdlyvdim0__opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0] 
            = __Vdlyvval__opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    }
    if (__Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram[__Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0] 
            = __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    }
    if (__Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram[__Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0] 
            = __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    }
    vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__force_timer_overflow_sync__DOT__sync_regs 
        = __Vdly__opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__force_timer_overflow_sync__DOT__sync_regs;
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_new_p3 
        = (0x1ffU & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_pre_p2) 
                     + (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__eg_inc_p2)));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_p3 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__next_state_p2;
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__self 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__next_self;
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__state 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__next_state;
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT____Vcellinp__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__wea 
        = (IData)(((~ ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__bank_num_p) 
                       >> 2U)) & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT____Vcellout__sample_clk_en_sr__out) 
                                  >> 2U)));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT____Vcellinp__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__wea 
        = (1U & (((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__bank_num_p) 
                  & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT____Vcellout__sample_clk_en_sr__out)) 
                 >> 2U));
    if (((((0U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num)) 
           || (1U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num))) 
          || (2U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num))) 
         || (0xcU == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num)))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__use_feedback_p1 = 1U;
    } else if ((((((((((3U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num)) 
                       || (4U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num))) 
                      || (5U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num))) 
                     || (9U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num))) 
                    || (0xaU == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num))) 
                   || (0xbU == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num))) 
                  || (0xfU == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num))) 
                 || (0x10U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num))) 
                || (0x11U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num)))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__use_feedback_p1 = 0U;
    } else if ((6U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__use_feedback_p1 
            = (1U & ((0x12U < (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state))
                      ? (~ ((IData)(vlSelf->opl3__DOT__channels__DOT__connection_sel) 
                            >> 3U)) : (~ (IData)(vlSelf->opl3__DOT__channels__DOT__connection_sel))));
    } else if ((7U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__use_feedback_p1 
            = (1U & ((0x12U < (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state))
                      ? (~ ((IData)(vlSelf->opl3__DOT__channels__DOT__connection_sel) 
                            >> 4U)) : (~ ((IData)(vlSelf->opl3__DOT__channels__DOT__connection_sel) 
                                          >> 1U))));
    } else if ((8U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__use_feedback_p1 
            = (1U & ((0x12U < (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state))
                      ? (~ ((IData)(vlSelf->opl3__DOT__channels__DOT__connection_sel) 
                            >> 5U)) : (~ ((IData)(vlSelf->opl3__DOT__channels__DOT__connection_sel) 
                                          >> 2U))));
    } else if (((0xdU == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num)) 
                || (0xeU == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num)))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__use_feedback_p1 
            = (1U & (~ ((0x12U >= (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state)) 
                        & (IData)(vlSelf->opl3__DOT__channels__DOT__ryt))));
    }
    vlSelf->sample_valid = vlSelf->opl3__DOT__channels__DOT__dac_prep__DOT__sample_valid_opl3_p1;
    vlSelf->opl3__DOT__channels__DOT__channel_valid 
        = (1U & (vlSelf->opl3__DOT__channels__DOT__signals 
                 >> 4U));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_p1 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT____Vcellout__state_mem__dob;
    opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__rate_hi_pre_p1 
        = (0x1fU & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__rate_p1) 
                    >> 2U));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__rate_hi_p1 
        = ((0x10U & (IData)(opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__rate_hi_pre_p1))
            ? 0xfU : (0xfU & (IData)(opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__rate_hi_pre_p1)));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__rate_lo_p1 
        = (3U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__rate_p1));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_shift_p1 
        = (0x3fU & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__rate_hi_p1) 
                    + (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_add)));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__env_shift_pre_p1 
        = (7U & ((3U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__rate_hi_p1)) 
                 + (1U & (0x8aeU >> (0xfU & (VL_SHIFTL_III(4,32,32, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__rate_lo_p1), 2U) 
                                             + (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__eg_timer_lo)))))));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__requested_rate_not_zero_p1 
        = (0U != (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__requested_rate_p0));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__out_p6 
        = (0x1fffU & (VL_SHIFTR_III(13,32,13, (0x800U 
                                               | VL_SHIFTL_III(32,32,32, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__exp_out_p5), 1U)), 
                                    (0x1fffU & VL_SHIFTR_III(13,13,32, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__level_p5), 8U))) 
                      ^ (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__neg_p5)));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__dob_array[1U] 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__genblk1__DOT__dob_p1;
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__dob_array[0U] 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__genblk1__DOT__dob_p1;
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__dob_array[1U] 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__genblk1__DOT__dob_p1;
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__dob_array[0U] 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__genblk1__DOT__dob_p1;
    vlSelf->sample_r = vlSelf->opl3__DOT__channels__DOT__dac_prep__DOT__sample_opl3_r_p1;
    if ((0x10U & vlSelf->opl3__DOT__channels__DOT__signals)) {
        vlSelf->opl3__DOT__channels__DOT__channel_r 
            = (VL_LTS_III(32, 0x7fffU, VL_EXTENDS_II(32,20, 
                                                     (0xfffffU 
                                                      & vlSelf->opl3__DOT__channels__DOT__self[0U])))
                ? 0x7fffU : (VL_GTS_III(32, 0xffff8000U, 
                                        VL_EXTENDS_II(32,20, 
                                                      (0xfffffU 
                                                       & vlSelf->opl3__DOT__channels__DOT__self[0U])))
                              ? 0x8000U : (0xffffU 
                                           & vlSelf->opl3__DOT__channels__DOT__self[0U])));
        vlSelf->opl3__DOT__channels__DOT__channel_l 
            = (VL_LTS_III(32, 0x7fffU, VL_EXTENDS_II(32,20, 
                                                     (0xfffffU 
                                                      & ((vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                          << 0xcU) 
                                                         | (vlSelf->opl3__DOT__channels__DOT__self[0U] 
                                                            >> 0x14U)))))
                ? 0x7fffU : (VL_GTS_III(32, 0xffff8000U, 
                                        VL_EXTENDS_II(32,20, 
                                                      (0xfffffU 
                                                       & ((vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                           << 0xcU) 
                                                          | (vlSelf->opl3__DOT__channels__DOT__self[0U] 
                                                             >> 0x14U)))))
                              ? 0x8000U : (0xffffU 
                                           & ((vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                               << 0xcU) 
                                              | (vlSelf->opl3__DOT__channels__DOT__self[0U] 
                                                 >> 0x14U)))));
    }
    if (vlSelf->opl3__DOT__sample_clk_en) {
        vlSelf->opl3__DOT__channels__DOT__state = 0U;
        vlSelf->opl3__DOT__channels__DOT__self[0U] = 0U;
        vlSelf->opl3__DOT__channels__DOT__self[1U] = 0U;
        vlSelf->opl3__DOT__channels__DOT__self[2U] = 0U;
    } else {
        vlSelf->opl3__DOT__channels__DOT__state = vlSelf->opl3__DOT__channels__DOT__next_state;
        vlSelf->opl3__DOT__channels__DOT__self[0U] 
            = vlSelf->opl3__DOT__channels__DOT__next_self[0U];
        vlSelf->opl3__DOT__channels__DOT__self[1U] 
            = vlSelf->opl3__DOT__channels__DOT__next_self[1U];
        vlSelf->opl3__DOT__channels__DOT__self[2U] 
            = vlSelf->opl3__DOT__channels__DOT__next_self[2U];
    }
    vlSelf->sample_l = vlSelf->opl3__DOT__channels__DOT__dac_prep__DOT__sample_opl3_l_p1;
    vlSelf->opl3__DOT__channels__DOT__operator_out_mem__DOT__dob_array[1U] 
        = vlSelf->opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__genblk1__DOT__dob_p1;
    vlSelf->opl3__DOT__channels__DOT__operator_out_mem__DOT__dob_array[0U] 
        = vlSelf->opl3__DOT__channels__DOT__operator_out_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__genblk1__DOT__dob_p1;
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__dob_array[1U] 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__genblk1__DOT__dob_p1;
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__dob_array[0U] 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__genblk1__DOT__dob_p1;
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__dob_array[1U] 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__genblk1__DOT__genblk1__DOT__dob_p2;
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__dob_array[0U] 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__genblk1__DOT__genblk1__DOT__dob_p2;
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__env_p3 
        = (0x7ffU & ((((0x1ffU & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_p 
                                  >> 9U)) + (0xffU 
                                             & VL_SHIFTL_III(8,8,32, 
                                                             (0x3fU 
                                                              & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__tl_p 
                                                                 >> 6U)), 2U))) 
                      + (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__ksl_add_p2)) 
                     + ((0x80U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__am_vib_egt_ksr_mult_mem__dob))
                         ? (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__am_val_p2)
                         : 0U)));
    if ((0x20000U & vlSelf->opl3__DOT__opl3_reg_wr)) {
        if ((IData)((0x800U == (0x1ff00U & vlSelf->opl3__DOT__opl3_reg_wr)))) {
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__nts 
                = (1U & (vlSelf->opl3__DOT__opl3_reg_wr 
                         >> 6U));
        }
        if ((IData)((0xbd00U == (0x1ff00U & vlSelf->opl3__DOT__opl3_reg_wr)))) {
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__hh 
                = (1U & vlSelf->opl3__DOT__opl3_reg_wr);
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__tc 
                = (1U & (vlSelf->opl3__DOT__opl3_reg_wr 
                         >> 1U));
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__tom 
                = (1U & (vlSelf->opl3__DOT__opl3_reg_wr 
                         >> 2U));
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__sd 
                = (1U & (vlSelf->opl3__DOT__opl3_reg_wr 
                         >> 3U));
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__bd 
                = (1U & (vlSelf->opl3__DOT__opl3_reg_wr 
                         >> 4U));
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__dvb 
                = (1U & (vlSelf->opl3__DOT__opl3_reg_wr 
                         >> 6U));
        }
        if ((IData)((0x10500U == (0x1ff00U & vlSelf->opl3__DOT__opl3_reg_wr)))) {
            vlSelf->opl3__DOT__channels__DOT__is_new 
                = (1U & vlSelf->opl3__DOT__opl3_reg_wr);
        }
        if ((IData)((0x300U == (0x1ff00U & vlSelf->opl3__DOT__opl3_reg_wr)))) {
            vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer2 
                = (0xffU & vlSelf->opl3__DOT__opl3_reg_wr);
        }
        if ((IData)((0x200U == (0x1ff00U & vlSelf->opl3__DOT__opl3_reg_wr)))) {
            vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer1 
                = (0xffU & vlSelf->opl3__DOT__opl3_reg_wr);
        }
        if ((IData)((0x400U == (0x1ff00U & vlSelf->opl3__DOT__opl3_reg_wr)))) {
            vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__st2 
                = (1U & (vlSelf->opl3__DOT__opl3_reg_wr 
                         >> 1U));
        }
    }
    if (vlSelf->opl3__DOT__reset_sync__DOT__r2) {
        vlSelf->opl3__DOT__channels__DOT__is_new = 0U;
        vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer2 = 0U;
        vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer1 = 0U;
        vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__st2 = 0U;
    }
    if (vlSelf->force_clear_flags) {
        vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__st2 = 0U;
    }
    if ((0x20000U & vlSelf->opl3__DOT__opl3_reg_wr)) {
        if ((IData)((0x400U == (0x1ff00U & vlSelf->opl3__DOT__opl3_reg_wr)))) {
            vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__st1 
                = (1U & vlSelf->opl3__DOT__opl3_reg_wr);
        }
    }
    if (vlSelf->opl3__DOT__reset_sync__DOT__r2) {
        vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__st1 = 0U;
    }
    if (vlSelf->force_clear_flags) {
        vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__st1 = 0U;
    }
    vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer2_overflow_pulse 
        = ((0xffU == (IData)(vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer2_inst__DOT__timer)) 
           & (IData)(vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer2_inst__DOT__tick_pulse));
    vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__irq 
        = ((IData)(vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__ft1) 
           | (IData)(vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__ft2));
    vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer1_overflow_pulse 
        = ((0xffU == (IData)(vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer1_inst__DOT__timer)) 
           & (IData)(vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer1_inst__DOT__tick_pulse));
    vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__irq_rst = 0U;
    if ((0x20000U & vlSelf->opl3__DOT__opl3_reg_wr)) {
        if ((IData)((0x400U == (0x1ff00U & vlSelf->opl3__DOT__opl3_reg_wr)))) {
            vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__mt2 
                = (1U & (vlSelf->opl3__DOT__opl3_reg_wr 
                         >> 5U));
            vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__mt1 
                = (1U & (vlSelf->opl3__DOT__opl3_reg_wr 
                         >> 6U));
            vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__irq_rst 
                = (1U & (vlSelf->opl3__DOT__opl3_reg_wr 
                         >> 7U));
        }
        if ((IData)((0xbd00U == (0x1ff00U & vlSelf->opl3__DOT__opl3_reg_wr)))) {
            vlSelf->opl3__DOT__channels__DOT__ryt = 
                (1U & (vlSelf->opl3__DOT__opl3_reg_wr 
                       >> 5U));
        }
        if ((IData)((0x10400U == (0x1ff00U & vlSelf->opl3__DOT__opl3_reg_wr)))) {
            vlSelf->opl3__DOT__channels__DOT__connection_sel 
                = (0x3fU & vlSelf->opl3__DOT__opl3_reg_wr);
        }
    }
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_p3 
        = ((2U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT____Vcellout__eg_reset_sr__out))
            ? 0U : (0xfffffU & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_p2 
                                + ((2U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT____Vcellout__vib_sr__out))
                                    ? (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT__post_mult_p2 
                                       + (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT__vib_val_p2))
                                    : vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT__post_mult_p2))));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT____Vcellout__vib_sr__out 
        = __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT____Vcellout__vib_sr__out;
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT____Vcellout__eg_reset_sr__out 
        = __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT____Vcellout__eg_reset_sr__out;
    opl3__DOT__channels__DOT__control_operators__DOT__cnt1_p1 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__dob_array
        [(1U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt1_mem__DOT__bankb_p))];
    opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fb_cnt0_mem__dob 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__dob_array
        [(1U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankb_p))];
    vlSelf->opl3__DOT__channels__DOT__operator_mem_out 
        = vlSelf->opl3__DOT__channels__DOT__operator_out_mem__DOT__dob_array
        [(1U & (IData)(vlSelf->opl3__DOT__channels__DOT__operator_out_mem__DOT__bankb_p))];
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT____Vcellout__feedback_mem__dob 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__dob_array
        [(1U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_mem__DOT__bankb_p))];
    if (__Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram[__Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0] 
            = __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    }
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_p2 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__dob_array
        [(1U & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankb_p) 
                >> 1U))];
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__hh_phase_p2 
        = (0x3ffU & ((2U == (7U & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__op_type_p) 
                                   >> 3U))) ? (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_p2 
                                               >> 9U)
                      : (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__hh_phase_friend)));
    if (__Vdlyvset__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram[__Vdlyvdim0__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0] 
            = __Vdlyvval__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram__v0;
    }
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__tl_p 
        = __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__tl_p;
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_p 
        = __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_p;
    vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer2_inst__DOT__timer 
        = __Vdly__opl3__DOT__genblk1__DOT__timers__DOT__timer2_inst__DOT__timer;
    vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer2_inst__DOT__tick_pulse 
        = (0x2a2fU == (IData)(vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer2_inst__DOT__tick_counter));
    vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer1_inst__DOT__timer 
        = __Vdly__opl3__DOT__genblk1__DOT__timers__DOT__timer1_inst__DOT__timer;
    vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer1_inst__DOT__tick_pulse 
        = (0xa8bU == (IData)(vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer1_inst__DOT__tick_counter));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT__vib_val_p2 
        = (7U & ((0U != (4U & VL_SHIFTR_III(32,32,32, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT__vibrato__DOT__vibrato_index_p1), 0xaU)))
                  ? (~ (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT__vibrato__DOT__delta2_p1))
                  : (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT__vibrato__DOT__delta2_p1)));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT__post_mult_p2 
        = (0xfffffU & VL_SHIFTR_III(20,20,32, (0xfffffU 
                                               & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT__pre_mult_p1 
                                                  * (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT__multiplier_p1))), 1U));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__next_self 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__self;
    if ((0U == vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__state)) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__next_self = 0U;
    } else if ((1U == vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__state)) {
        if ((8U == (0xfU & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__self) 
                            >> 1U)))) {
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__next_self 
                = (0x21U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__next_self));
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__next_self 
                = ((0x20U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__self))
                    ? (1U | (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__next_self))
                    : ((0x1fU & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__next_self)) 
                       | (0x20U & (((IData)(1U) + ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__self) 
                                                   >> 5U)) 
                                   << 5U))));
        } else {
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__next_self 
                = ((0x21U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__next_self)) 
                   | (0x1eU & (((IData)(1U) + ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__self) 
                                               >> 1U)) 
                               << 1U)));
        }
    }
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__next_state;
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT____Vcellinp__feedback_mem__dia 
        = ((0x3ffe000U & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT____Vcellout__feedback_sr__out[3U] 
                          << 5U)) | (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__out_p6));
    vlSelf->opl3__DOT__channels__DOT__operator_out 
        = ((0x1fffU & vlSelf->opl3__DOT__channels__DOT__operator_out) 
           | ((0x80000U & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__sample_clk_en_sr__out) 
                           << 0xeU)) | ((0x40000U & 
                                         ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__bank_num_p) 
                                          << 0xdU)) 
                                        | (0x3e000U 
                                           & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p 
                                              >> 0xcU)))));
    vlSelf->opl3__DOT__channels__DOT__operator_out 
        = ((0xfe000U & vlSelf->opl3__DOT__channels__DOT__operator_out) 
           | (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__out_p6));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__level_p5 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__level_p4;
    __Vtableidx5 = (0xffU & (~ (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__post_gain_p4)));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__exp_out_p5 
        = Vopl3__ConstPool__TABLE_h40e95e60_0[__Vtableidx5];
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__neg_p5 
        = (0x1fffU & ((((0U == (7U & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__ws_post_opl_p 
                                      >> 9U))) || (6U 
                                                   == 
                                                   (7U 
                                                    & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__ws_post_opl_p 
                                                       >> 9U)))) 
                       || (7U == (7U & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__ws_post_opl_p 
                                        >> 9U)))) ? 
                      ((0x200U & vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__final_phase_p)
                        ? 0xffffffffU : 0U) : ((4U 
                                                == 
                                                (7U 
                                                 & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__ws_post_opl_p 
                                                    >> 9U)))
                                                ? (
                                                   (1U 
                                                    == 
                                                    (3U 
                                                     & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__final_phase_p 
                                                        >> 8U)))
                                                    ? 0xffffffffU
                                                    : 0U)
                                                : 0U)));
    if ((((((((((((((0U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p1)) 
                    || (1U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p1))) 
                   || (2U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p1))) 
                  || (0xcU == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p1))) 
                 || (0xdU == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p1))) 
                || (0xeU == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p1))) 
               | ((((3U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p1)) 
                    || (4U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p1))) 
                   || (5U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p1))) 
                  || (0xfU == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p1)))) 
              | (6U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p1))) 
             | (7U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p1))) 
            | (8U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p1))) 
           | (9U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p1))) 
          | (0xaU == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p1))) 
         | (0xbU == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p1)))) {
        if (((((((0U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p1)) 
                 || (1U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p1))) 
                || (2U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p1))) 
               || (0xcU == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p1))) 
              || (0xdU == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p1))) 
             || (0xeU == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p1)))) {
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__modulation_p1 = 0U;
        } else if (((((3U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p1)) 
                      || (4U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p1))) 
                     || (5U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p1))) 
                    || (0xfU == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p1)))) {
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__modulation_p1 
                = ((1U & (IData)(opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fb_cnt0_mem__dob))
                    ? 0U : (0x1fffU & VL_EXTENDS_II(32,13, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__modulation_out_p1))));
        } else if ((6U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p1))) {
            if ((1U & (((~ (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__bank_num_p1)) 
                        & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__connection_sel_p1)) 
                       | ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__bank_num_p1) 
                          & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__connection_sel_p1) 
                             >> 3U))))) {
                if ((((0U == ((2U & ((IData)(opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fb_cnt0_mem__dob) 
                                     << 1U)) | (IData)(opl3__DOT__channels__DOT__control_operators__DOT__cnt1_p1))) 
                      || (2U == ((2U & ((IData)(opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fb_cnt0_mem__dob) 
                                        << 1U)) | (IData)(opl3__DOT__channels__DOT__control_operators__DOT__cnt1_p1)))) 
                     || (3U == ((2U & ((IData)(opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fb_cnt0_mem__dob) 
                                       << 1U)) | (IData)(opl3__DOT__channels__DOT__control_operators__DOT__cnt1_p1))))) {
                    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__modulation_p1 
                        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__modulation_out_p1;
                } else if ((1U == ((2U & ((IData)(opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fb_cnt0_mem__dob) 
                                          << 1U)) | (IData)(opl3__DOT__channels__DOT__control_operators__DOT__cnt1_p1)))) {
                    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__modulation_p1 = 0U;
                }
            } else {
                vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__modulation_p1 = 0U;
            }
        } else if ((7U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p1))) {
            if ((1U & (((~ (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__bank_num_p1)) 
                        & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__connection_sel_p1) 
                           >> 1U)) | ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__bank_num_p1) 
                                      & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__connection_sel_p1) 
                                         >> 4U))))) {
                if ((((0U == ((2U & ((IData)(opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fb_cnt0_mem__dob) 
                                     << 1U)) | (IData)(opl3__DOT__channels__DOT__control_operators__DOT__cnt1_p1))) 
                      || (2U == ((2U & ((IData)(opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fb_cnt0_mem__dob) 
                                        << 1U)) | (IData)(opl3__DOT__channels__DOT__control_operators__DOT__cnt1_p1)))) 
                     || (3U == ((2U & ((IData)(opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fb_cnt0_mem__dob) 
                                       << 1U)) | (IData)(opl3__DOT__channels__DOT__control_operators__DOT__cnt1_p1))))) {
                    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__modulation_p1 
                        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__modulation_out_p1;
                } else if ((1U == ((2U & ((IData)(opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fb_cnt0_mem__dob) 
                                          << 1U)) | (IData)(opl3__DOT__channels__DOT__control_operators__DOT__cnt1_p1)))) {
                    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__modulation_p1 = 0U;
                }
            } else {
                vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__modulation_p1 = 0U;
            }
        } else if ((8U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p1))) {
            if ((1U & (((~ (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__bank_num_p1)) 
                        & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__connection_sel_p1) 
                           >> 2U)) | ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__bank_num_p1) 
                                      & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__connection_sel_p1) 
                                         >> 5U))))) {
                if ((((0U == ((2U & ((IData)(opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fb_cnt0_mem__dob) 
                                     << 1U)) | (IData)(opl3__DOT__channels__DOT__control_operators__DOT__cnt1_p1))) 
                      || (2U == ((2U & ((IData)(opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fb_cnt0_mem__dob) 
                                        << 1U)) | (IData)(opl3__DOT__channels__DOT__control_operators__DOT__cnt1_p1)))) 
                     || (3U == ((2U & ((IData)(opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fb_cnt0_mem__dob) 
                                       << 1U)) | (IData)(opl3__DOT__channels__DOT__control_operators__DOT__cnt1_p1))))) {
                    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__modulation_p1 
                        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__modulation_out_p1;
                } else if ((1U == ((2U & ((IData)(opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fb_cnt0_mem__dob) 
                                          << 1U)) | (IData)(opl3__DOT__channels__DOT__control_operators__DOT__cnt1_p1)))) {
                    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__modulation_p1 = 0U;
                }
            } else {
                vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__modulation_p1 = 0U;
            }
        } else if ((9U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p1))) {
            if ((1U & (((~ (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__bank_num_p1)) 
                        & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__connection_sel_p1)) 
                       | ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__bank_num_p1) 
                          & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__connection_sel_p1) 
                             >> 3U))))) {
                if ((((0U == ((2U & ((IData)(opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fb_cnt0_mem__dob) 
                                     << 1U)) | (IData)(opl3__DOT__channels__DOT__control_operators__DOT__cnt1_p1))) 
                      || (1U == ((2U & ((IData)(opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fb_cnt0_mem__dob) 
                                        << 1U)) | (IData)(opl3__DOT__channels__DOT__control_operators__DOT__cnt1_p1)))) 
                     || (2U == ((2U & ((IData)(opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fb_cnt0_mem__dob) 
                                       << 1U)) | (IData)(opl3__DOT__channels__DOT__control_operators__DOT__cnt1_p1))))) {
                    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__modulation_p1 
                        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__modulation_out_p1;
                } else if ((3U == ((2U & ((IData)(opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fb_cnt0_mem__dob) 
                                          << 1U)) | (IData)(opl3__DOT__channels__DOT__control_operators__DOT__cnt1_p1)))) {
                    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__modulation_p1 = 0U;
                }
            } else {
                vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__modulation_p1 
                    = ((1U & (IData)(opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fb_cnt0_mem__dob))
                        ? 0U : (0x1fffU & VL_EXTENDS_II(32,13, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__modulation_out_p1))));
            }
        } else if ((0xaU == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p1))) {
            if ((1U & (((~ (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__bank_num_p1)) 
                        & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__connection_sel_p1) 
                           >> 1U)) | ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__bank_num_p1) 
                                      & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__connection_sel_p1) 
                                         >> 4U))))) {
                if ((((0U == ((2U & ((IData)(opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fb_cnt0_mem__dob) 
                                     << 1U)) | (IData)(opl3__DOT__channels__DOT__control_operators__DOT__cnt1_p1))) 
                      || (1U == ((2U & ((IData)(opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fb_cnt0_mem__dob) 
                                        << 1U)) | (IData)(opl3__DOT__channels__DOT__control_operators__DOT__cnt1_p1)))) 
                     || (2U == ((2U & ((IData)(opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fb_cnt0_mem__dob) 
                                       << 1U)) | (IData)(opl3__DOT__channels__DOT__control_operators__DOT__cnt1_p1))))) {
                    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__modulation_p1 
                        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__modulation_out_p1;
                } else if ((3U == ((2U & ((IData)(opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fb_cnt0_mem__dob) 
                                          << 1U)) | (IData)(opl3__DOT__channels__DOT__control_operators__DOT__cnt1_p1)))) {
                    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__modulation_p1 = 0U;
                }
            } else {
                vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__modulation_p1 
                    = ((1U & (IData)(opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fb_cnt0_mem__dob))
                        ? 0U : (0x1fffU & VL_EXTENDS_II(32,13, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__modulation_out_p1))));
            }
        } else if ((1U & (((~ (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__bank_num_p1)) 
                           & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__connection_sel_p1) 
                              >> 2U)) | ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__bank_num_p1) 
                                         & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__connection_sel_p1) 
                                            >> 5U))))) {
            if ((((0U == ((2U & ((IData)(opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fb_cnt0_mem__dob) 
                                 << 1U)) | (IData)(opl3__DOT__channels__DOT__control_operators__DOT__cnt1_p1))) 
                  || (1U == ((2U & ((IData)(opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fb_cnt0_mem__dob) 
                                    << 1U)) | (IData)(opl3__DOT__channels__DOT__control_operators__DOT__cnt1_p1)))) 
                 || (2U == ((2U & ((IData)(opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fb_cnt0_mem__dob) 
                                   << 1U)) | (IData)(opl3__DOT__channels__DOT__control_operators__DOT__cnt1_p1))))) {
                vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__modulation_p1 
                    = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__modulation_out_p1;
            } else if ((3U == ((2U & ((IData)(opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fb_cnt0_mem__dob) 
                                      << 1U)) | (IData)(opl3__DOT__channels__DOT__control_operators__DOT__cnt1_p1)))) {
                vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__modulation_p1 = 0U;
            }
        } else {
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__modulation_p1 
                = ((1U & (IData)(opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fb_cnt0_mem__dob))
                    ? 0U : (0x1fffU & VL_EXTENDS_II(32,13, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__modulation_out_p1))));
        }
    } else if (((0x10U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p1)) 
                || (0x11U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num_p1)))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__modulation_p1 
            = ((1U & ((IData)(opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fb_cnt0_mem__dob) 
                      | ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ryt_p1) 
                         & (~ (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__bank_num_p1)))))
                ? 0U : (0x1fffU & VL_EXTENDS_II(32,13, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__modulation_out_p1))));
    }
    opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_result_tmp_p1 
        = ((0U == (7U & ((IData)(opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fb_cnt0_mem__dob) 
                         >> 1U))) ? 0U : (0x3fffffU 
                                          & ((VL_EXTENDS_II(32,13, 
                                                            (0x1fffU 
                                                             & vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT____Vcellout__feedback_mem__dob)) 
                                              + VL_EXTENDS_II(32,13, 
                                                              (0x1fffU 
                                                               & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT____Vcellout__feedback_mem__dob 
                                                                  >> 0xdU)))) 
                                             << (7U 
                                                 & ((IData)(opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fb_cnt0_mem__dob) 
                                                    >> 1U)))));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_result_p1 
        = (0x1fffU & VL_SHIFTRS_III(22,22,32, opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__feedback_result_tmp_p1, 9U));
    opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__tc_phase_p2 
        = (0x3ffU & ((5U == (7U & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__op_type_p) 
                                   >> 3U))) ? (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__phase_acc_p2 
                                               >> 9U)
                      : (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__tc_phase_friend)));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__rm_xor_p2 
        = (1U & (((((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__hh_phase_p2) 
                    >> 2U) ^ ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__hh_phase_p2) 
                              >> 7U)) | (((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__hh_phase_p2) 
                                          >> 3U) ^ 
                                         ((IData)(opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__tc_phase_p2) 
                                          >> 5U))) 
                 | (((IData)(opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__tc_phase_p2) 
                     >> 3U) ^ ((IData)(opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__calc_rhythm_phase__DOT__tc_phase_p2) 
                               >> 5U))));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_pre_p2 
        = (0x1ffU & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_p 
                     >> 9U));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__eg_inc_p2 = 0U;
    opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__eg_off_p2 = 0U;
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__next_state_p2 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_p2;
    opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_extra_bits_p2 
        = (0x1ffU & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_p 
                     >> 9U));
    opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__sl_increased_p2 
        = ((0xfU == (0xfU & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__sl_p) 
                             >> 4U))) ? 0x1fU : (0xfU 
                                                 & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__sl_p) 
                                                    >> 4U)));
    if ((((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT____Vcellout__eg_reset_sr__out) 
          >> 1U) & (0xfU == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__rate_hi_p2)))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_pre_p2 = 0U;
    }
    if ((0x1f8U == (0x1f8U & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_p 
                              >> 9U)))) {
        opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__eg_off_p2 = 1U;
    }
    if ((((1U != (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_p2)) 
          & (~ ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT____Vcellout__eg_reset_sr__out) 
                >> 1U))) & (IData)(opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__eg_off_p2))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_pre_p2 = 0x1ffU;
    }
    if ((8U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_p2))) {
        if ((1U & (~ ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_p2) 
                      >> 2U)))) {
            if ((1U & (~ ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_p2) 
                          >> 1U)))) {
                if ((1U & (~ (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_p2)))) {
                    if ((((~ (IData)(opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__eg_off_p2)) 
                          & (~ ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT____Vcellout__eg_reset_sr__out) 
                                >> 1U))) & (0U < (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_shift_p2)))) {
                        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__eg_inc_p2 
                            = (0x1ffU & VL_SHIFTL_III(9,32,32, (IData)(1U), 
                                                      ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_shift_p2) 
                                                       - (IData)(1U))));
                    }
                }
            }
        }
    } else if ((4U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_p2))) {
        if ((1U & (~ ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_p2) 
                      >> 1U)))) {
            if ((1U & (~ (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_p2)))) {
                if ((((~ (IData)(opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__eg_off_p2)) 
                      & (~ ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT____Vcellout__eg_reset_sr__out) 
                            >> 1U))) & (0U < (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_shift_p2)))) {
                    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__eg_inc_p2 
                        = (0x1ffU & VL_SHIFTL_III(9,32,32, (IData)(1U), 
                                                  ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_shift_p2) 
                                                   - (IData)(1U))));
                }
            }
        }
    } else if ((2U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_p2))) {
        if ((1U & (~ (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_p2)))) {
            if (((0x1ffU & VL_SHIFTR_III(9,9,32, (0x1ffU 
                                                  & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_p 
                                                     >> 9U)), 4U)) 
                 == (IData)(opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__sl_increased_p2))) {
                vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__next_state_p2 = 4U;
            } else if ((((~ (IData)(opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__eg_off_p2)) 
                         & (~ ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT____Vcellout__eg_reset_sr__out) 
                               >> 1U))) & (0U < (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_shift_p2)))) {
                vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__eg_inc_p2 
                    = (0x1ffU & VL_SHIFTL_III(9,32,32, (IData)(1U), 
                                              ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_shift_p2) 
                                               - (IData)(1U))));
            }
        }
    } else if ((1U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_p2))) {
        if ((0U == (0x1ffU & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_p 
                              >> 9U)))) {
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__next_state_p2 = 2U;
        } else if (((((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT____Vcellout__key_on_sr__out) 
                      >> 1U) & (0U < (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_shift_p2))) 
                    & (0xfU != (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__rate_hi_p2)))) {
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__eg_inc_p2 
                = (0x1ffU & VL_SHIFTR_III(12,12,32, 
                                          (0xfffU & 
                                           (~ (IData)(opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_extra_bits_p2))), 
                                          ((IData)(4U) 
                                           - (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_shift_p2))));
        }
    }
    if ((2U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT____Vcellout__eg_reset_sr__out))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__next_state_p2 = 1U;
    }
    if ((1U & (~ ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT____Vcellout__key_on_sr__out) 
                  >> 1U)))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__next_state_p2 = 8U;
    }
    if ((0U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__ksl_add_rom__DOT__ksl_p1))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__ksl_add_p2 = 0U;
    } else if ((1U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__ksl_add_rom__DOT__ksl_p1))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__ksl_add_p2 
            = (VL_GTES_III(32, 0U, VL_EXTENDS_II(32,8, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__ksl_add_rom__DOT__tmp1_p1)))
                ? 0U : (0xffU & VL_SHIFTL_III(32,32,32, 
                                              VL_EXTENDS_II(32,8, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__ksl_add_rom__DOT__tmp1_p1)), 1U)));
    } else if ((2U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__ksl_add_rom__DOT__ksl_p1))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__ksl_add_p2 
            = (VL_GTES_III(32, 0U, VL_EXTENDS_II(32,8, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__ksl_add_rom__DOT__tmp1_p1)))
                ? 0U : (0xffU & VL_EXTENDS_II(32,8, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__ksl_add_rom__DOT__tmp1_p1))));
    } else if ((3U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__ksl_add_rom__DOT__ksl_p1))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__ksl_add_p2 
            = (VL_GTES_III(32, 0U, VL_EXTENDS_II(32,8, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__ksl_add_rom__DOT__tmp1_p1)))
                ? 0U : (0xffU & VL_SHIFTL_III(32,32,32, 
                                              VL_EXTENDS_II(32,8, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__ksl_add_rom__DOT__tmp1_p1)), 2U)));
    }
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__am_val_p2 
        = (0x3fU & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__tremolo__DOT__dam_p1)
                     ? (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__tremolo__DOT__am_val_tmp1_p1)
                     : VL_SHIFTR_III(6,6,32, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__tremolo__DOT__am_val_tmp1_p1), 2U)));
    vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer2_inst__DOT__start_timer_set_pulse 
        = ((~ (IData)(vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer2_inst__DOT__start_timer_edge_detect__DOT__in_r0)) 
           & (IData)(vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__st2));
    vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer1_inst__DOT__start_timer_set_pulse 
        = ((~ (IData)(vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__timer1_inst__DOT__start_timer_edge_detect__DOT__in_r0)) 
           & (IData)(vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__st1));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT__vibrato__DOT__vibrato_index_p1 
        = __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT__vibrato__DOT__vibrato_index_p1;
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__final_phase_p 
        = __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__final_phase_p;
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__ws_post_opl_p 
        = __Vdly__opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__ws_post_opl_p;
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__ksl_add_rom__DOT__tmp1_p1 
        = (0xffU & VL_EXTENDS_II(8,7, (0x7fU & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__ksl_add_rom__DOT__rom_out_p1) 
                                                + VL_SHIFTL_III(7,7,32, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__ksl_add_rom__DOT__tmp0_p1), 3U)))));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__tremolo__DOT__am_val_tmp1_p1 
        = (0x3fU & ((0x1aU < (0x3fU & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__tremolo__DOT__tremolo_index_p1) 
                                       >> 8U))) ? ((IData)(0x34U) 
                                                   + 
                                                   (~ 
                                                    ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__tremolo__DOT__tremolo_index_p1) 
                                                     >> 8U)))
                     : ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__tremolo__DOT__tremolo_index_p1) 
                        >> 8U)));
    opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT__vibrato__DOT__delta1_p1 
        = (7U & ((3U == (3U & VL_SHIFTR_III(32,32,32, (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT__vibrato__DOT__vibrato_index_p1), 0xaU)))
                  ? VL_SHIFTR_III(3,3,32, (7U & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT__vibrato__DOT__fnum_p1) 
                                                 >> 7U)), 1U)
                  : ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT__vibrato__DOT__fnum_p1) 
                     >> 7U)));
    __Vtableidx2 = (0xfU & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__am_vib_egt_ksr_mult_mem__dob));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT__multiplier_p1 
        = Vopl3__ConstPool__TABLE_hecfd1f27_0[__Vtableidx2];
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT__pre_mult_p1 
        = (0x1ffffU & VL_SHIFTR_III(17,17,32, (0x1ffffU 
                                               & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fnum) 
                                                  << 
                                                  (7U 
                                                   & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__block_fnum_high_mem__dob) 
                                                      >> 2U)))), 1U));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_sample_clk_en 
        = ((0U != (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state)) 
           & (0U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__delay_counter)));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__final_phase_p3 
        = (0x3ffU & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__rhythm_phase_p3) 
                     + ((vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__modulation_p[0U] 
                         << 0x13U) | (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__modulation_p[0U] 
                                      >> 0xdU))));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__theta_p3 
        = (0xffU & ((((0U == (7U & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__ws_post_opl_p 
                                    >> 6U))) || (1U 
                                                 == 
                                                 (7U 
                                                  & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__ws_post_opl_p 
                                                     >> 6U)))) 
                     || (2U == (7U & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__ws_post_opl_p 
                                      >> 6U)))) ? (
                                                   (0x100U 
                                                    & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__final_phase_p3))
                                                    ? 
                                                   (0xffU 
                                                    ^ 
                                                    (0xffU 
                                                     & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__final_phase_p3)))
                                                    : 
                                                   (0xffU 
                                                    & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__final_phase_p3)))
                     : ((3U == (7U & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__ws_post_opl_p 
                                      >> 6U))) ? (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__final_phase_p3)
                         : (((4U == (7U & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__ws_post_opl_p 
                                           >> 6U))) 
                             || (5U == (7U & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__ws_post_opl_p 
                                              >> 6U))))
                             ? ((0x80U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__final_phase_p3))
                                 ? (0x1feU ^ VL_SHIFTL_III(32,32,32, 
                                                           (0xffU 
                                                            & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__final_phase_p3)), 1U))
                                 : VL_SHIFTL_III(32,32,32, 
                                                 (0xffU 
                                                  & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__final_phase_p3)), 1U))
                             : (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__final_phase_p3)))));
    if (((0U == (7U & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__ws_post_opl_p 
                       >> 9U))) || (2U == (7U & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__ws_post_opl_p 
                                                 >> 9U))))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__pre_gain_p4 
            = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__log_sin_out_p4;
    } else if ((((1U == (7U & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__ws_post_opl_p 
                               >> 9U))) || (4U == (7U 
                                                   & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__ws_post_opl_p 
                                                      >> 9U)))) 
                || (5U == (7U & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__ws_post_opl_p 
                                 >> 9U))))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__pre_gain_p4 
            = ((0x200U & vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__final_phase_p)
                ? 0x1000U : (0x1fffU & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__log_sin_out_p4)));
    } else if ((3U == (7U & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__ws_post_opl_p 
                             >> 9U)))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__pre_gain_p4 
            = ((0x100U & vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__final_phase_p)
                ? 0x1000U : (0x1fffU & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__log_sin_out_p4)));
    } else if ((6U == (7U & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__ws_post_opl_p 
                             >> 9U)))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__pre_gain_p4 = 0U;
    } else if ((7U == (7U & (vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__ws_post_opl_p 
                             >> 9U)))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__pre_gain_p4 
            = (0x1fffU & VL_SHIFTL_III(13,32,32, ((0x200U 
                                                   & vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__final_phase_p)
                                                   ? 
                                                  (0x1ffU 
                                                   ^ 
                                                   (0x1ffU 
                                                    & vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__final_phase_p))
                                                   : 
                                                  (0x3ffU 
                                                   & vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__final_phase_p)), 3U));
    }
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__post_gain_p4 
        = (0x7fffU & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__pre_gain_p4) 
                      + (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__env_shifted_p4)));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__level_p4 
        = ((0x1fffU < (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__post_gain_p4))
            ? 0x1fffU : (0x1fffU & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__post_gain_p4)));
    vlSelf->opl3__DOT__sample_clk_en = (0x2a9U == (IData)(vlSelf->opl3__DOT__sample_clk_gen__DOT__counter));
    if ((0U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num = 0U;
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__next_state 
            = (0x3fU & (IData)(vlSelf->opl3__DOT__sample_clk_en));
    } else {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num 
            = (0x1fU & ((0x12U < (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state))
                         ? (((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state) 
                             - (IData)(0x12U)) - (IData)(1U))
                         : ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state) 
                            - (IData)(1U))));
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__next_state 
            = (0x3fU & ((1U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__delay_counter))
                         ? ((0x24U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state))
                             ? 0U : ((IData)(1U) + (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state)))
                         : (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state)));
    }
    vlSelf->opl3__DOT__channels__DOT__next_state = vlSelf->opl3__DOT__channels__DOT__state;
    if (((((((((0U == vlSelf->opl3__DOT__channels__DOT__state) 
               | (1U == vlSelf->opl3__DOT__channels__DOT__state)) 
              | (2U == vlSelf->opl3__DOT__channels__DOT__state)) 
             | (3U == vlSelf->opl3__DOT__channels__DOT__state)) 
            | (4U == vlSelf->opl3__DOT__channels__DOT__state)) 
           | (5U == vlSelf->opl3__DOT__channels__DOT__state)) 
          | (6U == vlSelf->opl3__DOT__channels__DOT__state)) 
         | (7U == vlSelf->opl3__DOT__channels__DOT__state))) {
        if ((0U == vlSelf->opl3__DOT__channels__DOT__state)) {
            if (vlSelf->opl3__DOT__channels__DOT__ops_done_pulse) {
                vlSelf->opl3__DOT__channels__DOT__next_state = 1U;
            }
        } else {
            vlSelf->opl3__DOT__channels__DOT__next_state 
                = ((1U == vlSelf->opl3__DOT__channels__DOT__state)
                    ? 2U : ((2U == vlSelf->opl3__DOT__channels__DOT__state)
                             ? 3U : ((3U == vlSelf->opl3__DOT__channels__DOT__state)
                                      ? ((8U == (0xfU 
                                                 & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                    >> 8U)))
                                          ? ((0x20000U 
                                              & vlSelf->opl3__DOT__channels__DOT__self[1U])
                                              ? 4U : 1U)
                                          : 1U) : (
                                                   (4U 
                                                    == vlSelf->opl3__DOT__channels__DOT__state)
                                                    ? 5U
                                                    : 
                                                   ((5U 
                                                     == vlSelf->opl3__DOT__channels__DOT__state)
                                                     ? 6U
                                                     : 
                                                    ((6U 
                                                      == vlSelf->opl3__DOT__channels__DOT__state)
                                                      ? 7U
                                                      : 
                                                     ((2U 
                                                       == 
                                                       (0xfU 
                                                        & (vlSelf->opl3__DOT__channels__DOT__self[1U] 
                                                           >> 8U)))
                                                       ? 
                                                      ((0x20000U 
                                                        & vlSelf->opl3__DOT__channels__DOT__self[1U])
                                                        ? 8U
                                                        : 4U)
                                                       : 4U)))))));
        }
    } else if ((8U == vlSelf->opl3__DOT__channels__DOT__state)) {
        vlSelf->opl3__DOT__channels__DOT__next_state = 0U;
    }
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__ksl_add_rom__DOT__ksl_p1 
        = (3U & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__ksl_tl_mem__dob) 
                 >> 6U));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__tremolo__DOT__dam_p1 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__dam;
    if ((0x20000U & vlSelf->opl3__DOT__opl3_reg_wr)) {
        if ((IData)((0xbd00U == (0x1ff00U & vlSelf->opl3__DOT__opl3_reg_wr)))) {
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__dam 
                = (1U & (vlSelf->opl3__DOT__opl3_reg_wr 
                         >> 7U));
        }
    }
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT__vibrato__DOT__delta2_p1 
        = (7U & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT__vibrato__DOT__dvb_p1)
                  ? (IData)(opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT__vibrato__DOT__delta1_p1)
                  : VL_SHIFTR_III(3,3,32, (IData)(opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__calc_phase_inc__DOT__vibrato__DOT__delta1_p1), 1U)));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__reb_mem 
        = ((0x12U >= (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state)) 
           & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_sample_clk_en));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__reb_mem 
        = ((0x12U < (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state)) 
           & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_sample_clk_en));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__op_type_p0 = 0U;
    if ((0x11U >= (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__dob_array[0U] 
            = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram
            [vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num];
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__dob_array[1U] 
            = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram
            [vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num];
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__dob_array[0U] 
            = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram
            [vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num];
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__dob_array[1U] 
            = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram
            [vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num];
    } else {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__dob_array[0U] = 0U;
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__env_int_mem__DOT__dob_array[1U] = 0U;
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__dob_array[0U] = 0U;
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__dob_array[1U] = 0U;
    }
    opl3__DOT__channels__DOT__control_operators__DOT__operator_mem_rd_address 
        = (0x1fU & ((6U > (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num))
                     ? (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num)
                     : ((0xcU > (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num))
                         ? ((IData)(2U) + (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num))
                         : ((IData)(4U) + (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num)))));
    if (vlSelf->opl3__DOT__reset_sync__DOT__r2) {
        vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__mt2 = 0U;
        vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__mt1 = 0U;
        vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__irq_rst = 0U;
        vlSelf->opl3__DOT__channels__DOT__connection_sel = 0U;
    }
    __Vtableidx1 = (((IData)(vlSelf->opl3__DOT__channels__DOT__connection_sel) 
                     << 6U) | (((0x12U < (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state)) 
                                << 5U) | (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num)));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__cnt1_channel_mem_rd_address 
        = Vopl3__ConstPool__TABLE_h38f42766_0[__Vtableidx1];
    if ((2U & Vopl3__ConstPool__TABLE_h0637a799_0[__Vtableidx1])) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_block_fnum_channel_mem_rd_address 
            = Vopl3__ConstPool__TABLE_hc80edecc_0[__Vtableidx1];
    }
    if ((4U & Vopl3__ConstPool__TABLE_h0637a799_0[__Vtableidx1])) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_channel_mem_rd_address 
            = Vopl3__ConstPool__TABLE_h6daf335f_0[__Vtableidx1];
    }
    vlSelf->opl3__DOT__sample_clk_gen__DOT__counter 
        = __Vdly__opl3__DOT__sample_clk_gen__DOT__counter;
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT____Vcellout__state_mem__dob 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__state_mem__DOT__dob_array
        [(0x12U < (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state))];
    if ((0x15U >= (IData)(opl3__DOT__channels__DOT__control_operators__DOT__operator_mem_rd_address))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__dob_array[0U] 
            = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram
            [opl3__DOT__channels__DOT__control_operators__DOT__operator_mem_rd_address];
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__dob_array[1U] 
            = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram
            [opl3__DOT__channels__DOT__control_operators__DOT__operator_mem_rd_address];
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__dob_array[0U] 
            = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram
            [opl3__DOT__channels__DOT__control_operators__DOT__operator_mem_rd_address];
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__dob_array[1U] 
            = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram
            [opl3__DOT__channels__DOT__control_operators__DOT__operator_mem_rd_address];
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__dob_array[0U] 
            = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram
            [opl3__DOT__channels__DOT__control_operators__DOT__operator_mem_rd_address];
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__dob_array[1U] 
            = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram
            [opl3__DOT__channels__DOT__control_operators__DOT__operator_mem_rd_address];
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__dob_array[0U] 
            = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram
            [opl3__DOT__channels__DOT__control_operators__DOT__operator_mem_rd_address];
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__dob_array[1U] 
            = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram
            [opl3__DOT__channels__DOT__control_operators__DOT__operator_mem_rd_address];
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__dob_array[0U] 
            = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram
            [opl3__DOT__channels__DOT__control_operators__DOT__operator_mem_rd_address];
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__dob_array[1U] 
            = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram
            [opl3__DOT__channels__DOT__control_operators__DOT__operator_mem_rd_address];
    } else {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__dob_array[0U] = 0U;
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__dob_array[1U] = 0U;
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__dob_array[0U] = 0U;
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__dob_array[1U] = 0U;
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__dob_array[0U] = 0U;
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__dob_array[1U] = 0U;
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__dob_array[0U] = 0U;
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__dob_array[1U] = 0U;
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__dob_array[0U] = 0U;
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__dob_array[1U] = 0U;
    }
    if ((8U >= (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_block_fnum_channel_mem_rd_address))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__dob_array[0U] 
            = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram
            [vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_block_fnum_channel_mem_rd_address];
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__dob_array[1U] 
            = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram
            [vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_block_fnum_channel_mem_rd_address];
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__dob_array[0U] 
            = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram
            [vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_block_fnum_channel_mem_rd_address];
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__dob_array[1U] 
            = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram
            [vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_block_fnum_channel_mem_rd_address];
    } else {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__dob_array[0U] = 0U;
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__dob_array[1U] = 0U;
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__dob_array[0U] = 0U;
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__dob_array[1U] = 0U;
    }
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__dob_array[0U] 
        = ((8U >= (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_block_fnum_channel_mem_rd_address)) 
           && vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__DOT__ram
           [vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_block_fnum_channel_mem_rd_address]);
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__dob_array[1U] 
        = ((8U >= (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_block_fnum_channel_mem_rd_address)) 
           && vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__DOT__ram
           [vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_block_fnum_channel_mem_rd_address]);
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__ksl_tl_mem__dob 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ksl_tl_mem__DOT__dob_array
        [(0x12U < (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state))];
    opl3__DOT__channels__DOT__control_operators__DOT__ws 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ws_mem__DOT__dob_array
        [(0x12U < (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state))];
    opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__ar_dr_mem__dob 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__ar_dr_mem__DOT__dob_array
        [(0x12U < (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state))];
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__sl_rr_mem__dob 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__sl_rr_mem__DOT__dob_array
        [(0x12U < (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state))];
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__am_vib_egt_ksr_mult_mem__dob 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__am_vib_egt_ksr_mult_mem__DOT__dob_array
        [(0x12U < (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state))];
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fnum_low_mem__dob 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fnum_low_mem__DOT__dob_array
        [(0x12U < (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state))];
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__key_on_p0 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__dob_array
        [(0x12U < (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state))];
    if (((0x12U >= (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state)) 
         & (IData)(vlSelf->opl3__DOT__channels__DOT__ryt))) {
        if (((0xcU == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num)) 
             || (0xfU == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num)))) {
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__op_type_p0 = 1U;
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__key_on_p0 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__bd;
        } else if ((0xdU == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num))) {
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__op_type_p0 = 2U;
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__key_on_p0 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__hh;
        } else if ((0xeU == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num))) {
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__op_type_p0 = 3U;
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__key_on_p0 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__tom;
        } else if ((0x10U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num))) {
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__op_type_p0 = 4U;
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__key_on_p0 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__sd;
        } else if ((0x11U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__op_num))) {
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__op_type_p0 = 5U;
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__key_on_p0 
                = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__tc;
        }
    }
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__block_fnum_high_mem__dob 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT__dob_array
        [(0x12U < (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__state))];
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__ws_post_opl_p0 
        = opl3__DOT__channels__DOT__control_operators__DOT__ws;
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__ws_post_opl_p0 
        = ((3U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__phase_generator__DOT__ws_post_opl_p0)) 
           | (0xfffffffcU & ((IData)(opl3__DOT__channels__DOT__control_operators__DOT__ws) 
                             & ((IData)(vlSelf->opl3__DOT__channels__DOT__is_new) 
                                << 2U))));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__eg_reset_p0 = 0U;
    if (((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__key_on_p0) 
         & (8U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT____Vcellout__state_mem__dob)))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__eg_reset_p0 = 1U;
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__requested_rate_p0 
            = (0xfU & ((IData)(opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__ar_dr_mem__dob) 
                       >> 4U));
    } else if ((1U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT____Vcellout__state_mem__dob))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__requested_rate_p0 
            = (0xfU & ((IData)(opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__ar_dr_mem__dob) 
                       >> 4U));
    } else if ((2U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT____Vcellout__state_mem__dob))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__requested_rate_p0 
            = (0xfU & (IData)(opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__ar_dr_mem__dob));
    } else if ((4U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT____Vcellout__state_mem__dob))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__requested_rate_p0 
            = ((0x20U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__am_vib_egt_ksr_mult_mem__dob))
                ? 0U : (0xfU & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__sl_rr_mem__dob)));
    } else if ((8U == (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT____Vcellout__state_mem__dob))) {
        vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__requested_rate_p0 
            = (0xfU & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__sl_rr_mem__dob));
    }
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fnum 
        = ((0x300U & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__block_fnum_high_mem__dob) 
                      << 8U)) | (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__fnum_low_mem__dob));
    vlSelf->opl3__DOT__opl3_reg_wr = (0x1ffffU & vlSelf->opl3__DOT__opl3_reg_wr);
    if ((1U & (~ (IData)(vlSelf->opl3__DOT__host_if__DOT__opl3_fifo_empty)))) {
        if ((0x100U & (IData)(vlSelf->opl3__DOT__host_if__DOT____Vcellout__afifo__o_rd_data))) {
            vlSelf->opl3__DOT__opl3_reg_wr = ((0x3ff00U 
                                               & vlSelf->opl3__DOT__opl3_reg_wr) 
                                              | (0xffU 
                                                 & (IData)(vlSelf->opl3__DOT__host_if__DOT____Vcellout__afifo__o_rd_data)));
            vlSelf->opl3__DOT__opl3_reg_wr = (0x20000U 
                                              | vlSelf->opl3__DOT__opl3_reg_wr);
        } else {
            vlSelf->opl3__DOT__opl3_reg_wr = ((0x200ffU 
                                               & vlSelf->opl3__DOT__opl3_reg_wr) 
                                              | ((0x10000U 
                                                  & ((IData)(vlSelf->opl3__DOT__host_if__DOT____Vcellout__afifo__o_rd_data) 
                                                     << 7U)) 
                                                 | (0xff00U 
                                                    & ((IData)(vlSelf->opl3__DOT__host_if__DOT____Vcellout__afifo__o_rd_data) 
                                                       << 8U))));
        }
    }
    if (vlSelf->opl3__DOT__reset_sync__DOT__r2) {
        vlSelf->opl3__DOT__opl3_reg_wr = 0U;
    }
    opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__block_shifted 
        = (0xfU & VL_SHIFTL_III(4,4,32, (7U & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__block_fnum_high_mem__dob) 
                                               >> 2U)), 1U));
    opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__ksv_p0 
        = ((IData)(opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__block_shifted) 
           | ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__nts)
               ? (1U & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fnum) 
                        >> 8U)) : (1U & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fnum) 
                                         >> 9U))));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__ks_p0 
        = (0xfU & ((0x10U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellout__am_vib_egt_ksr_mult_mem__dob))
                    ? (IData)(opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__ksv_p0)
                    : VL_SHIFTR_III(4,4,32, (IData)(opl3__DOT__channels__DOT__control_operators__DOT__operator__DOT__envelope_generator__DOT__calc_envelope_shift__DOT__ksv_p0), 2U)));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellinp__am_vib_egt_ksr_mult_mem__wea 
        = ((vlSelf->opl3__DOT__opl3_reg_wr >> 0x11U) 
           & ((0x20U <= (0xffU & (vlSelf->opl3__DOT__opl3_reg_wr 
                                  >> 8U))) & (0x35U 
                                              >= (0xffU 
                                                  & (vlSelf->opl3__DOT__opl3_reg_wr 
                                                     >> 8U)))));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellinp__ksl_tl_mem__wea 
        = ((vlSelf->opl3__DOT__opl3_reg_wr >> 0x11U) 
           & ((0x40U <= (0xffU & (vlSelf->opl3__DOT__opl3_reg_wr 
                                  >> 8U))) & (0x55U 
                                              >= (0xffU 
                                                  & (vlSelf->opl3__DOT__opl3_reg_wr 
                                                     >> 8U)))));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellinp__ar_dr_mem__wea 
        = ((vlSelf->opl3__DOT__opl3_reg_wr >> 0x11U) 
           & ((0x60U <= (0xffU & (vlSelf->opl3__DOT__opl3_reg_wr 
                                  >> 8U))) & (0x75U 
                                              >= (0xffU 
                                                  & (vlSelf->opl3__DOT__opl3_reg_wr 
                                                     >> 8U)))));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellinp__sl_rr_mem__wea 
        = ((vlSelf->opl3__DOT__opl3_reg_wr >> 0x11U) 
           & ((0x80U <= (0xffU & (vlSelf->opl3__DOT__opl3_reg_wr 
                                  >> 8U))) & (0x95U 
                                              >= (0xffU 
                                                  & (vlSelf->opl3__DOT__opl3_reg_wr 
                                                     >> 8U)))));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellinp__ws_mem__wea 
        = ((vlSelf->opl3__DOT__opl3_reg_wr >> 0x11U) 
           & ((0xe0U <= (0xffU & (vlSelf->opl3__DOT__opl3_reg_wr 
                                  >> 8U))) & (0xf5U 
                                              >= (0xffU 
                                                  & (vlSelf->opl3__DOT__opl3_reg_wr 
                                                     >> 8U)))));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT____Vcellinp__fnum_low_mem__wea 
        = ((vlSelf->opl3__DOT__opl3_reg_wr >> 0x11U) 
           & ((0xa0U <= (0xffU & (vlSelf->opl3__DOT__opl3_reg_wr 
                                  >> 8U))) & (0xa8U 
                                              >= (0xffU 
                                                  & (vlSelf->opl3__DOT__opl3_reg_wr 
                                                     >> 8U)))));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT____Vcellinp__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__dia 
        = ((1U != vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__state) 
           & (vlSelf->opl3__DOT__opl3_reg_wr >> 5U));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT____Vcellinp__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__addra 
        = (0xfU & ((1U == vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__state)
                    ? ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__self) 
                       >> 1U) : (vlSelf->opl3__DOT__opl3_reg_wr 
                                 >> 8U)));
    opl3__DOT__channels__DOT____Vcellinp__ch_abcd_cnt_mem__wea 
        = ((vlSelf->opl3__DOT__opl3_reg_wr >> 0x11U) 
           & ((0xc0U <= (0xffU & (vlSelf->opl3__DOT__opl3_reg_wr 
                                  >> 8U))) & (0xc8U 
                                              >= (0xffU 
                                                  & (vlSelf->opl3__DOT__opl3_reg_wr 
                                                     >> 8U)))));
    opl3__DOT__channels__DOT__control_operators__DOT____Vcellinp__block_fnum_high_mem__wea 
        = ((vlSelf->opl3__DOT__opl3_reg_wr >> 0x11U) 
           & ((0xb0U <= (0xffU & (vlSelf->opl3__DOT__opl3_reg_wr 
                                  >> 8U))) & (0xb8U 
                                              >= (0xffU 
                                                  & (vlSelf->opl3__DOT__opl3_reg_wr 
                                                     >> 8U)))));
    vlSelf->opl3__DOT__host_if__DOT____Vcellout__afifo__o_rd_data 
        = vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__mem
        [(0x3fU & (IData)(vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__rd_addr))];
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT____Vcellinp__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__wea 
        = ((~ (vlSelf->opl3__DOT__opl3_reg_wr >> 0x10U)) 
           & (IData)(opl3__DOT__channels__DOT____Vcellinp__ch_abcd_cnt_mem__wea));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__fb_cnt0_mem__DOT____Vcellinp__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__wea 
        = ((vlSelf->opl3__DOT__opl3_reg_wr >> 0x10U) 
           & (IData)(opl3__DOT__channels__DOT____Vcellinp__ch_abcd_cnt_mem__wea));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT____Vcellinp__bankgen__BRA__0__KET____DOT__genblk1__DOT__mem_bank__wea 
        = ((~ (vlSelf->opl3__DOT__opl3_reg_wr >> 0x10U)) 
           & (IData)(opl3__DOT__channels__DOT__control_operators__DOT____Vcellinp__block_fnum_high_mem__wea));
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__block_fnum_high_mem__DOT____Vcellinp__bankgen__BRA__1__KET____DOT__genblk1__DOT__mem_bank__wea 
        = ((vlSelf->opl3__DOT__opl3_reg_wr >> 0x10U) 
           & (IData)(opl3__DOT__channels__DOT__control_operators__DOT____Vcellinp__block_fnum_high_mem__wea));
}

VL_INLINE_OPT void Vopl3___024root___nba_sequent__TOP__1(Vopl3___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vopl3__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vopl3___024root___nba_sequent__TOP__1\n"); );
    // Init
    SData/*15:0*/ __Vdly__opl3__DOT__host_if__DOT__dout_sync__DOT__sync_regs;
    __Vdly__opl3__DOT__host_if__DOT__dout_sync__DOT__sync_regs = 0;
    CData/*5:0*/ __Vdly__opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__host_rd_counter;
    __Vdly__opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__host_rd_counter = 0;
    CData/*5:0*/ __Vdlyvdim0__opl3__DOT__host_if__DOT__afifo__DOT__mem__v0;
    __Vdlyvdim0__opl3__DOT__host_if__DOT__afifo__DOT__mem__v0 = 0;
    SData/*9:0*/ __Vdlyvval__opl3__DOT__host_if__DOT__afifo__DOT__mem__v0;
    __Vdlyvval__opl3__DOT__host_if__DOT__afifo__DOT__mem__v0 = 0;
    CData/*0:0*/ __Vdlyvset__opl3__DOT__host_if__DOT__afifo__DOT__mem__v0;
    __Vdlyvset__opl3__DOT__host_if__DOT__afifo__DOT__mem__v0 = 0;
    // Body
    __Vdly__opl3__DOT__host_if__DOT__dout_sync__DOT__sync_regs 
        = vlSelf->opl3__DOT__host_if__DOT__dout_sync__DOT__sync_regs;
    __Vdlyvset__opl3__DOT__host_if__DOT__afifo__DOT__mem__v0 = 0U;
    __Vdly__opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__host_rd_counter 
        = vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__host_rd_counter;
    __Vdly__opl3__DOT__host_if__DOT__dout_sync__DOT__sync_regs 
        = ((0xff00U & ((IData)(vlSelf->opl3__DOT__host_if__DOT__dout_sync__DOT__sync_regs) 
                       << 8U)) | (IData)(vlSelf->opl3__DOT__status));
    if (((IData)(vlSelf->opl3__DOT__host_if__DOT____Vcellinp__afifo__i_wr) 
         & (~ (IData)(vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__o_wr_full)))) {
        __Vdlyvval__opl3__DOT__host_if__DOT__afifo__DOT__mem__v0 
            = (((IData)(vlSelf->opl3__DOT__host_if__DOT__address_p1) 
                << 8U) | (IData)(vlSelf->opl3__DOT__host_if__DOT__din_p1));
        __Vdlyvset__opl3__DOT__host_if__DOT__afifo__DOT__mem__v0 = 1U;
        __Vdlyvdim0__opl3__DOT__host_if__DOT__afifo__DOT__mem__v0 
            = (0x3fU & (IData)(vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__wr_addr));
    }
    vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__rd_p1_n 
        = vlSelf->rd_n;
    vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__wr_p1_n 
        = vlSelf->wr_n;
    vlSelf->opl3__DOT__host_if__DOT__host_status_p1 
        = (0xffU & ((IData)(vlSelf->opl3__DOT__host_if__DOT__dout_sync__DOT__sync_regs) 
                    >> 8U));
    vlSelf->opl3__DOT__host_if__DOT__wr_p2 = vlSelf->opl3__DOT__host_if__DOT__wr_p1;
    vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__cs_p1_n 
        = vlSelf->cs_n;
    vlSelf->opl3__DOT__host_if__DOT__wr_p1_n = vlSelf->wr_n;
    vlSelf->opl3__DOT__host_if__DOT__cs_p1_n = vlSelf->cs_n;
    if (((IData)((0x20401U == (0x3ff01U & vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__host_reg_wr))) 
         & (0xffU == (IData)(vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__timer1)))) {
        __Vdly__opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__host_rd_counter = 0U;
        vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__host_force_timer_overflow = 0U;
    }
    if ((((IData)(vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__start_counter) 
          & (IData)(vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__rd_p1)) 
         & (~ (IData)(vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__rd_p2)))) {
        __Vdly__opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__host_rd_counter 
            = (0x3fU & ((IData)(1U) + (IData)(vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__host_rd_counter)));
    }
    if (((IData)((0x20401U == (0x3ff01U & vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__host_reg_wr))) 
         & (0xffU == (IData)(vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__timer1)))) {
        vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__start_counter = 1U;
    }
    if ((0x32U == (IData)(vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__host_rd_counter))) {
        vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__host_force_timer_overflow = 1U;
    }
    if ((1U & ((~ (IData)(vlSelf->ic_n)) | ((vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__host_reg_wr 
                                             >> 0x11U) 
                                            & (~ (IData)(
                                                         (0x401U 
                                                          == 
                                                          (0x1ff01U 
                                                           & vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__host_reg_wr)))))))) {
        __Vdly__opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__host_rd_counter = 0U;
        vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__host_force_timer_overflow = 0U;
        vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__start_counter = 0U;
    }
    if (__Vdlyvset__opl3__DOT__host_if__DOT__afifo__DOT__mem__v0) {
        vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__mem[__Vdlyvdim0__opl3__DOT__host_if__DOT__afifo__DOT__mem__v0] 
            = __Vdlyvval__opl3__DOT__host_if__DOT__afifo__DOT__mem__v0;
    }
    vlSelf->opl3__DOT__host_if__DOT__dout_sync__DOT__sync_regs 
        = __Vdly__opl3__DOT__host_if__DOT__dout_sync__DOT__sync_regs;
    vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__host_rd_counter 
        = __Vdly__opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__host_rd_counter;
    vlSelf->opl3__DOT__host_if__DOT__din_p1 = vlSelf->din;
    vlSelf->opl3__DOT__host_if__DOT__address_p1 = vlSelf->address;
    vlSelf->opl3__DOT__host_if__DOT__wr_p1 = (1U & 
                                              ((~ (IData)(vlSelf->opl3__DOT__host_if__DOT__cs_p1_n)) 
                                               & (~ (IData)(vlSelf->opl3__DOT__host_if__DOT__wr_p1_n))));
    vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__rd_p2 
        = vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__rd_p1;
    vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__rd_p1 
        = (1U & ((~ (IData)(vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__cs_p1_n)) 
                 & (~ (IData)(vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__rd_p1_n))));
    vlSelf->dout = ((0U == (IData)(vlSelf->opl3__DOT__host_if__DOT__address_p1))
                     ? (IData)(vlSelf->opl3__DOT__host_if__DOT__host_status_p1)
                     : 0xffU);
    if ((IData)((0x20200U == (0x3ff00U & vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__host_reg_wr)))) {
        vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__timer1 
            = (0xffU & vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__host_reg_wr);
    }
    vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__host_reg_wr 
        = (0x1ffffU & vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__host_reg_wr);
    if (((IData)(vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__wr_p1) 
         & (~ (IData)(vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__wr_p2)))) {
        if ((1U & (IData)(vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__address_p1))) {
            vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__host_reg_wr 
                = (0x20000U | vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__host_reg_wr);
            vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__host_reg_wr 
                = ((0x3ff00U & vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__host_reg_wr) 
                   | (IData)(vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__din_p1));
        } else {
            vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__host_reg_wr 
                = ((0x200ffU & vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__host_reg_wr) 
                   | ((0x10000U & ((IData)(vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__address_p1) 
                                   << 0xfU)) | ((IData)(vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__din_p1) 
                                                << 8U)));
        }
    }
    if ((1U & (~ (IData)(vlSelf->ic_n)))) {
        vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__timer1 = 0U;
        vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__host_reg_wr = 0U;
    }
    vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__address_p1 
        = vlSelf->address;
    vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__din_p1 
        = vlSelf->din;
    vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__wr_p2 
        = vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__wr_p1;
    vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__wr_p1 
        = (1U & ((~ (IData)(vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__cs_p1_n)) 
                 & (~ (IData)(vlSelf->opl3__DOT__host_if__DOT__genblk1__DOT__trick_sw_detection__DOT__wr_p1_n))));
}

VL_INLINE_OPT void Vopl3___024root___nba_sequent__TOP__2(Vopl3___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vopl3__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vopl3___024root___nba_sequent__TOP__2\n"); );
    // Body
    if (vlSelf->ic_n) {
        vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__wr_rgray 
            = vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__rgray_cross;
        vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__rgray_cross 
            = vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__rgray;
    } else {
        vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__wr_rgray = 0U;
        vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__rgray_cross = 0U;
    }
}

VL_INLINE_OPT void Vopl3___024root___nba_sequent__TOP__3(Vopl3___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vopl3__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vopl3___024root___nba_sequent__TOP__3\n"); );
    // Body
    if (vlSelf->opl3__DOT__host_if__DOT____Vcellinp__afifo__i_rd_reset_n) {
        vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__rd_wgray 
            = vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__wgray_cross;
        if ((1U & (~ (IData)(vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__lcl_rd_empty)))) {
            vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__rgray 
                = (0x7fU & (((IData)(1U) + (IData)(vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__rd_addr)) 
                            ^ VL_SHIFTR_III(7,7,32, 
                                            (0x7fU 
                                             & ((IData)(1U) 
                                                + (IData)(vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__rd_addr))), 1U)));
            vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__rd_addr 
                = vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__next_rd_addr;
        }
        vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__wgray_cross 
            = vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__wgray;
    } else {
        vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__rd_wgray = 0U;
        vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__rgray = 0U;
        vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__wgray_cross = 0U;
        vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__rd_addr = 0U;
    }
    vlSelf->opl3__DOT__host_if__DOT__opl3_fifo_empty 
        = ((1U & (~ (IData)(vlSelf->opl3__DOT__host_if__DOT____Vcellinp__afifo__i_rd_reset_n))) 
           || (IData)(vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__lcl_rd_empty));
    vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__lcl_rd_empty 
        = ((IData)(vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__rd_wgray) 
           == (IData)(vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__rgray));
    vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__next_rd_addr 
        = (0x7fU & ((IData)(1U) + (IData)(vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__rd_addr)));
}

VL_INLINE_OPT void Vopl3___024root___nba_sequent__TOP__4(Vopl3___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vopl3__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vopl3___024root___nba_sequent__TOP__4\n"); );
    // Body
    vlSelf->opl3__DOT__reset_sync__DOT__r2 = ((1U & 
                                               (~ (IData)(vlSelf->ic_n))) 
                                              || (IData)(vlSelf->opl3__DOT__reset_sync__DOT__r1));
    vlSelf->opl3__DOT__host_if__DOT____Vcellinp__afifo__i_rd_reset_n 
        = (1U & (~ (IData)(vlSelf->opl3__DOT__reset_sync__DOT__r2)));
    vlSelf->opl3__DOT__reset_sync__DOT__r1 = ((1U & 
                                               (~ (IData)(vlSelf->ic_n))) 
                                              || (IData)(vlSelf->opl3__DOT__reset_sync__DOT__r0));
    vlSelf->opl3__DOT__reset_sync__DOT__r0 = (1U & 
                                              (~ (IData)(vlSelf->ic_n)));
}

VL_INLINE_OPT void Vopl3___024root___nba_sequent__TOP__5(Vopl3___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vopl3__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vopl3___024root___nba_sequent__TOP__5\n"); );
    // Body
    vlSelf->opl3__DOT__status = 0U;
    vlSelf->opl3__DOT__status = ((0x1fU & (IData)(vlSelf->opl3__DOT__status)) 
                                 | (((IData)(vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__irq) 
                                     << 7U) | (((IData)(vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__ft1) 
                                                << 6U) 
                                               | ((IData)(vlSelf->opl3__DOT__genblk1__DOT__timers__DOT__ft2) 
                                                  << 5U))));
}

VL_INLINE_OPT void Vopl3___024root___nba_sequent__TOP__6(Vopl3___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vopl3__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vopl3___024root___nba_sequent__TOP__6\n"); );
    // Body
    if (vlSelf->ic_n) {
        if (((IData)(vlSelf->opl3__DOT__host_if__DOT____Vcellinp__afifo__i_wr) 
             & (~ (IData)(vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__o_wr_full)))) {
            vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__wgray 
                = (0x7fU & (((IData)(1U) + (IData)(vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__wr_addr)) 
                            ^ VL_SHIFTR_III(7,7,32, 
                                            (0x7fU 
                                             & ((IData)(1U) 
                                                + (IData)(vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__wr_addr))), 1U)));
            vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__wr_addr 
                = vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__next_wr_addr;
        }
    } else {
        vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__wgray = 0U;
        vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__wr_addr = 0U;
    }
    vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__o_wr_full 
        = ((IData)(vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__wr_rgray) 
           == ((0x60U & ((~ ((IData)(vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__wgray) 
                             >> 5U)) << 5U)) | (0x1fU 
                                                & (IData)(vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__wgray))));
    vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__next_wr_addr 
        = (0x7fU & ((IData)(1U) + (IData)(vlSelf->opl3__DOT__host_if__DOT__afifo__DOT__wr_addr)));
}

VL_INLINE_OPT void Vopl3___024root___nba_comb__TOP__1(Vopl3___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vopl3__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vopl3___024root___nba_comb__TOP__1\n"); );
    // Body
    vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__next_state 
        = vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__state;
    if ((0U == vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__state)) {
        if (vlSelf->opl3__DOT__reset_sync__DOT__r2) {
            vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__next_state = 1U;
        }
    } else if ((1U == vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__state)) {
        if ((8U == (0xfU & ((IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__self) 
                            >> 1U)))) {
            if ((0x20U & (IData)(vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__self))) {
                vlSelf->opl3__DOT__channels__DOT__control_operators__DOT__kon_mem__DOT__next_state = 0U;
            }
        }
    }
}

VL_INLINE_OPT void Vopl3___024root___nba_sequent__TOP__7(Vopl3___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vopl3__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vopl3___024root___nba_sequent__TOP__7\n"); );
    // Body
    vlSelf->opl3__DOT__host_if__DOT____Vcellinp__afifo__i_wr 
        = ((~ (IData)(vlSelf->opl3__DOT__host_if__DOT__wr_p2)) 
           & (IData)(vlSelf->opl3__DOT__host_if__DOT__wr_p1));
}

void Vopl3___024root___eval_nba(Vopl3___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vopl3__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vopl3___024root___eval_nba\n"); );
    // Body
    if ((8ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vopl3___024root___nba_sequent__TOP__0(vlSelf);
    }
    if ((4ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vopl3___024root___nba_sequent__TOP__1(vlSelf);
    }
    if ((0x10ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vopl3___024root___nba_sequent__TOP__2(vlSelf);
    }
    if ((0x20ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vopl3___024root___nba_sequent__TOP__3(vlSelf);
    }
    if ((9ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vopl3___024root___act_sequent__TOP__0(vlSelf);
    }
    if ((2ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vopl3___024root___nba_sequent__TOP__4(vlSelf);
    }
    if ((8ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vopl3___024root___nba_sequent__TOP__5(vlSelf);
    }
    if ((0x10ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vopl3___024root___nba_sequent__TOP__6(vlSelf);
    }
    if ((0xaULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vopl3___024root___nba_comb__TOP__1(vlSelf);
    }
    if ((4ULL & vlSelf->__VnbaTriggered.word(0U))) {
        Vopl3___024root___nba_sequent__TOP__7(vlSelf);
    }
}

void Vopl3___024root___eval_triggers__act(Vopl3___024root* vlSelf);

bool Vopl3___024root___eval_phase__act(Vopl3___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vopl3__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vopl3___024root___eval_phase__act\n"); );
    // Init
    VlTriggerVec<6> __VpreTriggered;
    CData/*0:0*/ __VactExecute;
    // Body
    Vopl3___024root___eval_triggers__act(vlSelf);
    __VactExecute = vlSelf->__VactTriggered.any();
    if (__VactExecute) {
        __VpreTriggered.andNot(vlSelf->__VactTriggered, vlSelf->__VnbaTriggered);
        vlSelf->__VnbaTriggered.thisOr(vlSelf->__VactTriggered);
        Vopl3___024root___eval_act(vlSelf);
    }
    return (__VactExecute);
}

bool Vopl3___024root___eval_phase__nba(Vopl3___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vopl3__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vopl3___024root___eval_phase__nba\n"); );
    // Init
    CData/*0:0*/ __VnbaExecute;
    // Body
    __VnbaExecute = vlSelf->__VnbaTriggered.any();
    if (__VnbaExecute) {
        Vopl3___024root___eval_nba(vlSelf);
        vlSelf->__VnbaTriggered.clear();
    }
    return (__VnbaExecute);
}

#ifdef VL_DEBUG
VL_ATTR_COLD void Vopl3___024root___dump_triggers__nba(Vopl3___024root* vlSelf);
#endif  // VL_DEBUG
#ifdef VL_DEBUG
VL_ATTR_COLD void Vopl3___024root___dump_triggers__act(Vopl3___024root* vlSelf);
#endif  // VL_DEBUG

void Vopl3___024root___eval(Vopl3___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vopl3__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vopl3___024root___eval\n"); );
    // Init
    IData/*31:0*/ __VnbaIterCount;
    CData/*0:0*/ __VnbaContinue;
    // Body
    __VnbaIterCount = 0U;
    __VnbaContinue = 1U;
    while (__VnbaContinue) {
        if (VL_UNLIKELY((0x64U < __VnbaIterCount))) {
#ifdef VL_DEBUG
            Vopl3___024root___dump_triggers__nba(vlSelf);
#endif
            VL_FATAL_MT("/mnt/c/Users/alber/proyectosAI/msx/MSX_up/fpga/opl3/opl3.sv", 44, "", "NBA region did not converge.");
        }
        __VnbaIterCount = ((IData)(1U) + __VnbaIterCount);
        __VnbaContinue = 0U;
        vlSelf->__VactIterCount = 0U;
        vlSelf->__VactContinue = 1U;
        while (vlSelf->__VactContinue) {
            if (VL_UNLIKELY((0x64U < vlSelf->__VactIterCount))) {
#ifdef VL_DEBUG
                Vopl3___024root___dump_triggers__act(vlSelf);
#endif
                VL_FATAL_MT("/mnt/c/Users/alber/proyectosAI/msx/MSX_up/fpga/opl3/opl3.sv", 44, "", "Active region did not converge.");
            }
            vlSelf->__VactIterCount = ((IData)(1U) 
                                       + vlSelf->__VactIterCount);
            vlSelf->__VactContinue = 0U;
            if (Vopl3___024root___eval_phase__act(vlSelf)) {
                vlSelf->__VactContinue = 1U;
            }
        }
        if (Vopl3___024root___eval_phase__nba(vlSelf)) {
            __VnbaContinue = 1U;
        }
    }
}

#ifdef VL_DEBUG
void Vopl3___024root___eval_debug_assertions(Vopl3___024root* vlSelf) {
    if (false && vlSelf) {}  // Prevent unused
    Vopl3__Syms* const __restrict vlSymsp VL_ATTR_UNUSED = vlSelf->vlSymsp;
    VL_DEBUG_IF(VL_DBG_MSGF("+    Vopl3___024root___eval_debug_assertions\n"); );
    // Body
    if (VL_UNLIKELY((vlSelf->clk & 0xfeU))) {
        Verilated::overWidthError("clk");}
    if (VL_UNLIKELY((vlSelf->clk_host & 0xfeU))) {
        Verilated::overWidthError("clk_host");}
    if (VL_UNLIKELY((vlSelf->clk_dac & 0xfeU))) {
        Verilated::overWidthError("clk_dac");}
    if (VL_UNLIKELY((vlSelf->ic_n & 0xfeU))) {
        Verilated::overWidthError("ic_n");}
    if (VL_UNLIKELY((vlSelf->cs_n & 0xfeU))) {
        Verilated::overWidthError("cs_n");}
    if (VL_UNLIKELY((vlSelf->rd_n & 0xfeU))) {
        Verilated::overWidthError("rd_n");}
    if (VL_UNLIKELY((vlSelf->wr_n & 0xfeU))) {
        Verilated::overWidthError("wr_n");}
    if (VL_UNLIKELY((vlSelf->address & 0xfcU))) {
        Verilated::overWidthError("address");}
    if (VL_UNLIKELY((vlSelf->force_clear_flags & 0xfeU))) {
        Verilated::overWidthError("force_clear_flags");}
}
#endif  // VL_DEBUG
