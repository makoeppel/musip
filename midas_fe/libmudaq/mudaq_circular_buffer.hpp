/**
 * access memory blocks as circular buffers
 *
 * @author      Moritz Kiehn <kiehn@physi.uni-heidelberg.de>
 * @date        2013-11-25
 */

#ifndef __MUDAQ_CIRCULAR_BUFFER_HPP_QKI1IAR0__
#define __MUDAQ_CIRCULAR_BUFFER_HPP_QKI1IAR0__

#include <ostream>
#include <type_traits>
#include <vector>

#include <cstdint>

namespace mudaq {

  /** access an existing small block of memory inside a bigger circular buffer */
  template<unsigned BUFFER_ORDER, typename T = uint32_t>
  class CircularSubBufferProxy
  {
  public:
    static const size_t BUFFER_SIZE = (1 << BUFFER_ORDER);
    static const size_t BUFFER_MASK = (BUFFER_SIZE - 1);

    CircularSubBufferProxy() : _base(nullptr), _offset(0), _size(0) {}
    CircularSubBufferProxy(volatile void* base, size_t offset, size_t size) :
      _base(static_cast<volatile T*>(base)), _offset(offset), _size(size) {}

    bool operator!() const { return (_base == nullptr); }
    T operator[](size_t idx) const
    {
      return _base[(_offset + idx) & BUFFER_MASK];
    }
    bool empty() const { return (_size == 0); }
    size_t size() const { return _size; }
    uint32_t give_offset() const {
      return _offset;
    }
    uint32_t give_end() const {
      return ( (_offset + _size - 1) & BUFFER_MASK );
    }

  private:
    volatile T* _base;
    size_t _offset;
    size_t _size;

    friend std::ostream& operator<<(std::ostream & os,
                                    const CircularSubBufferProxy& sub)
    {
      os << "CircularSubBufferProxy(";
      if (!sub) {
        os << "INVALID)";
      } else {
        os << "base=" << sub._base << ", "
           << "offset=" << sub._offset << ", "
           << "size=" << sub.size() << ")";
      }
    return os;
    }
  };

  /** access an existing block of memory as a circular buffer */
  template<unsigned O, typename T = uint32_t>
  class CircularBufferProxy
  {
  public:
    static const size_t BUFFER_ORDER = O;
    static const size_t BUFFER_SIZE = (1 << BUFFER_ORDER);
    static const size_t BUFFER_MASK = (BUFFER_SIZE - 1);

    typedef CircularSubBufferProxy<BUFFER_ORDER, T> SubBuffer;

    CircularBufferProxy() : _base(nullptr) {}
    CircularBufferProxy(void* base) : _base(static_cast<T*>(base)) {}

    bool operator!() const { return (_base == nullptr); }
    T operator[](size_t idx) const { return _base[idx & BUFFER_MASK]; }
    bool empty() const { return (BUFFER_SIZE == 0); }
    size_t size() const { return BUFFER_SIZE; }
    SubBuffer sub_buffer(size_t offset, size_t size) const
    {
      return SubBuffer(_base, offset, size);
    }

  private:
    T* _base;

    friend std::ostream& operator<<(std::ostream & os,
                                    const CircularBufferProxy& buf)
    {
        os << "CircularBufferProxy(";
        if (!buf) {
            os << "INVALID)";
        } else {
            os << "base=" << buf._base << ", "
               << "order=" << buf.BUFFER_ORDER << ", "
               << "size=" << buf.size() << ")";
        }
        return os;
    }
  };

  /** an fixed size circular buffer */
  template<unsigned O, typename T = uint32_t>
  class CircularBuffer : public CircularBufferProxy<O, T>
  {
  public:
    typedef CircularBufferProxy<O, T> Base;
    CircularBuffer() : _data(Base::BUFFER_SIZE, 0), Base(_data.data()) {}

  private:
    std::vector<T> _data;
  };

} // namespace mudaq

#endif // __MUDAQ_CIRCULAR_BUFFER_HPP_QKI1IAR0__
