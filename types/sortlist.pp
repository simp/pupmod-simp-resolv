# Valid resolv.conf `sortlist` field
type Resolv::Sortlist = Array[Variant[Simplib::IP,Simplib::IP::V4::DDQ,Simplib::IP::V6],0,10]
