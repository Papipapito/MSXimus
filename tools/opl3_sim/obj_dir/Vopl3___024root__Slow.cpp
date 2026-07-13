// Verilated -*- C++ -*-
// DESCRIPTION: Verilator output: Design implementation internals
// See Vopl3.h for the primary calling header

#include "Vopl3__pch.h"
#include "Vopl3__Syms.h"
#include "Vopl3___024root.h"

void Vopl3___024root___ctor_var_reset(Vopl3___024root* vlSelf);

Vopl3___024root::Vopl3___024root(Vopl3__Syms* symsp, const char* v__name)
    : VerilatedModule{v__name}
    , vlSymsp{symsp}
 {
    // Reset structure values
    Vopl3___024root___ctor_var_reset(this);
}

void Vopl3___024root::__Vconfigure(bool first) {
    if (false && first) {}  // Prevent unused
}

Vopl3___024root::~Vopl3___024root() {
}
