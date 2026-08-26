#pragma once

#define METALCPP_SYMBOL_VISIBILITY_HIDDEN
#include <Foundation/Foundation.hpp>

#include <Foundation/Foundation.h>

template <typename Native, typename C>
static Native* native(C* object) { return reinterpret_cast<Native*>(object); }

template <typename Native, typename C>
static const Native* native(const C* object) { return reinterpret_cast<const Native*>(object); }

template <typename C, typename Native>
static C* cobject(Native* object) { return reinterpret_cast<C*>(object); }

inline NS::String* nsString(const char* string)
{
    return string == nullptr ? nullptr : NS::String::string(string, NS::UTF8StringEncoding);
}

inline void returnError(NS::Error* error, NSError** output)
{
    if (output == nullptr) return;
    *output = nullptr;
    if (error != nullptr) {
        error->retain();
        *output = cobject<NSError>(error);
    }
}