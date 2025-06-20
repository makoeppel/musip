#pragma once

#include "musip/dqm/dqmfwd.hpp"

#include <mutex>
// Forward declarations of root types
class TH1F;
class TH1D;
class TH1I;
class TH2F;
class TH2D;
class TH2I;

namespace musip::dqm::detail {

/** @brief Used in place of std::lock_guard when you don't actually want to lock. Should be compiled away. */
template<typename mutex_type> struct FakeLockGuard{ FakeLockGuard(mutex_type&) {} };

/** @brief A struct that can used as a mutex object, but is actually a pointer to another mutex.
 *
 * This is used mainly so that thread locking for code that wants to lock a shared mutex can be disabled dynamically
 * at run time. If the pointer is nullptr no locking is performed.
 */
template<typename mutex_type = std::mutex>
struct MutexPointer {
    mutex_type* pMutex;
    MutexPointer(mutex_type* pMutex_) : pMutex(pMutex_) {}
    void lock() { if(pMutex != nullptr) pMutex->lock(); }
    bool try_lock() { if(pMutex != nullptr) return pMutex->try_lock(); else return true; }
    void unlock() { if(pMutex != nullptr) pMutex->unlock(); }

    bool operator==(const MutexPointer& other) { return pMutex == other.pMutex; } // Not sure if two nullptrs should return true or false here
};

/** @brief Helpers to choose between a real or fake lock depending on the value of the `Lock` enum. */
template<Lock lock, typename mutex_type> struct guard_type;
template<typename mutex_type> struct guard_type<Lock::PerformLock, mutex_type> { using type = std::lock_guard<mutex_type>; };
template<typename mutex_type> struct guard_type<Lock::AlreadyLocked, mutex_type> { using type = FakeLockGuard<mutex_type>; };

/** @brief Helper struct for std::visit. Copied from https://en.cppreference.com/w/cpp/utility/variant/visit. */
template<class... Ts>
struct overloaded : Ts... { using Ts::operator()...; };
// explicit deduction guide (not needed as of C++20)
template<class... Ts>
overloaded(Ts...) -> overloaded<Ts...>;

/** @brief Gives the equivalent root (as in root.cern.ch package) type for a histogram type. */
template<size_t dimensions, typename content_type> struct root_type;
template<> struct root_type<1,float> { using type = TH1F; };
template<> struct root_type<1,double> { using type = TH1D; };
template<> struct root_type<1,uint32_t> { using type = TH1I; };
template<> struct root_type<2,float> { using type = TH2F; };
template<> struct root_type<2,double> { using type = TH2D; };
template<> struct root_type<2,uint32_t> { using type = TH2I; };

} // end of namespace musip::dqm::detail
