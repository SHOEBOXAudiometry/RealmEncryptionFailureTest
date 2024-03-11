#  Realm encryption failure reproduction case

## Background
We have an app that has been using realm-swift v10.30. In the normal case, it uses two encrypted Realm databases; one that holds a small amount of data shared between all users of the app, and one that holds a much larger amount of data, that is user-specific. Some of the user-specific data has large objects containing hundreds of kilobytes or even megabytes of data, encoded as long strings. Both databases are opened on startup.

Our customers are intermittently encountering an issue where their Realm databases appear to become subtly corrupted, and writes to certain tables begin to fail - sometimes with a Swift exception that can be caught from `realm.write`, and sometimes with a C++ exception that crashes the app. 

We consistently see the following pattern in the customers' logs:

1. A "Decryption failure" error is thrown when writing new data. We have never seen this error when _reading_ an object from the database - only with writes. 
2. The failures begin to happen immediately after starting the app fresh, when both Realm databases are compacted via the `shouldCompactOnLaunch` callback. The affected customers frequently use the app successfully for hours during the previous session, with no problems. The compacting process on startup seems to corrupt the database.

After upgrading to realm-swift v10.46.0 we continued to see the same problems, so I created this test case based on the common usage patterns of the customers experiencing this issue. This seems to reproduce the problem.

## Steps to reproduce
This reproduces consistently on my iPad (7th generation) running iOS 17. It does _not_ reproduce in the iOS simulator.

Build the app and launch it on an iPad from Xcode. You will be presented with two buttons. Tap the first one, labelled "Create test database". The app will appear to do nothing for several minutes, but debug output should be visible in the Xcode console showing the progress in creating the two test databases. It is creating, updating, and deleting data in both databases, in a pattern matching the usage pattern of our customers; the logic is defined in the `StressTester` class.

When the process has completed, "Data creation is complete" will be printed into the Xcode console. At this point, you should force-quit the app and restart it.

Once restarted, tap the second button, labelled "Compact test database". This opens a backup copy of both databases, with the `shouldCompactOnLaunch` callback returning true, and then attempts to write one of each kind of object.

### Expected result
This completes successfully, and nothing happens.

### Actual result
The app crashes with an internal exception. Log output is below:

```
Opening file:///var/mobile/Containers/Data/Application/BC3C4F24-A24C-430F-8ABB-15BA0CB131CC/Documents/small.realm, size: 33 KB, data: 17 KB, compacting: true
Info: DB: 25633 Thread 0x211987840: DB compacted from: 32768 to 16544 in 29225 us
Opening file:///var/mobile/Containers/Data/Application/BC3C4F24-A24C-430F-8ABB-15BA0CB131CC/Documents/large.realm, size: 31.6 MB, data: 30.5 MB, compacting: true
Info: DB: 31425 Thread 0x211987840: DB compacted from: 31571968 to 30529568 in 1452647 us
/Users/jeremy/Library/Developer/Xcode/DerivedData/RealmEncryptionFailureTest-hgtivoaejsfynyeccpyzcpautrvd/SourcePackages/checkouts/realm-core/src/realm/util/encrypted_file_mapping.cpp:591: [realm-core-13.26.0] Assertion failed: is_not(e, Writable)
0   RealmEncryptionFailureTest          0x0000000104ee0d28 _ZN5realm4utilL18terminate_internalERNSt3__118basic_stringstreamIcNS1_11char_traitsIcEENS1_9allocatorIcEEEE + 28
1   RealmEncryptionFailureTest          0x0000000104ee0d08 _ZN5realm4util19terminate_with_infoEPKcS2_lS2_OSt16initializer_listINS0_9PrintableEE + 308
2   RealmEncryptionFailureTest          0x0000000104ee0bd4 _ZN5realm4util19terminate_with_infoEPKcS2_lS2_OSt16initializer_listINS0_9PrintableEE + 0
3   RealmEncryptionFailureTest          0x0000000104e918d0 _ZN5realm4util20EncryptedFileMappingD2Ev + 184
4   RealmEncryptionFailureTest          0x0000000104e91e94 _ZN5realm4util20EncryptedFileMappingD1Ev + 28
5   RealmEncryptionFailureTest          0x0000000104ed5e04 _ZNSt3__120__shared_ptr_emplaceIN5realm4util20EncryptedFileMappingENS_9allocatorIS3_EEE16__on_zero_sharedEv + 28
6   RealmEncryptionFailureTest          0x00000001046f1bb8 _ZNSt3__114__shared_count16__release_sharedB8ue170006Ev + 64
7   RealmEncryptionFailureTest          0x00000001046f1b58 _ZNSt3__119__shared_weak_count16__release_sharedB8ue170006Ev + 28
8   RealmEncryptionFailureTest          0x0000000104ed61ec _ZNSt3__110shared_ptrIN5realm4util20EncryptedFileMappingEED2B8ue170006Ev + 64
9   RealmEncryptionFailureTest          0x0000000104ed1788 _ZNSt3__110shared_ptrIN5realm4util20EncryptedFileMappingEED1B8ue170006Ev + 28
10  RealmEncryptionFailureTest          0x0000000104ed6680 _ZN5realm4util16mapping_and_addrD2Ev + 28
11  RealmEncryptionFailureTest          0x0000000104ed1838 _ZN5realm4util16mapping_and_addrD1Ev + 28
12  RealmEncryptionFailureTest          0x0000000104ed29dc _ZNSt3__19allocatorIN5realm4util16mapping_and_addrEE7destroyB8ue170006EPS3_ + 28
13  RealmEncryptionFailureTest          0x0000000104ed293c _ZNSt3__116allocator_traitsINS_9allocatorIN5realm4util16mapping_and_addrEEEE7destroyB8ue170006IS4_vEEvRS5_PT_ + 32
14  RealmEncryptionFailureTest          0x0000000104ed726c _ZNSt3__16vectorIN5realm4util16mapping_and_addrENS_9allocatorIS3_EEE22__base_destruct_at_endB8ue170006EPS3_ + 104
15  RealmEncryptionFailureTest          0x0000000104ed70b0 _ZNSt3__16vectorIN5realm4util16mapping_and_addrENS_9allocatorIS3_EEE17__destruct_at_endB8ue170006EPS3_ + 52
16  RealmEncryptionFailureTest          0x0000000104ed6f40 _ZNSt3__16vectorIN5realm4util16mapping_and_addrENS_9allocatorIS3_EEE5eraseB8ue170006ENS_11__wrap_iterIPKS3_EE + 116
17  RealmEncryptionFailureTest          0x0000000104eac900 _ZN5realm4util12_GLOBAL__N_114remove_mappingEPvm + 216
18  RealmEncryptionFailureTest          0x0000000104eac81c _ZN5realm4util24remove_encrypted_mappingEPvm + 32
19  RealmEncryptionFailureTest          0x0000000104ea97b0 _ZN5realm4util4File7MapBase5unmapEv + 160
20  RealmEncryptionFailureTest          0x00000001046963fc _ZN5realm4util4File3MapIcE5unmapEv + 24
21  RealmEncryptionFailureTest          0x00000001047afd34 _ZN5realm14WriteWindowMgr9MapWindowD2Ev + 40
22  RealmEncryptionFailureTest          0x00000001047afd6c _ZN5realm14WriteWindowMgr9MapWindowD1Ev + 28
23  RealmEncryptionFailureTest          0x00000001047bc300 _ZNKSt3__114default_deleteIN5realm14WriteWindowMgr9MapWindowEEclB8ue170006EPS3_ + 52
24  RealmEncryptionFailureTest          0x00000001047bc2bc _ZNSt3__110unique_ptrIN5realm14WriteWindowMgr9MapWindowENS_14default_deleteIS3_EEE5resetB8ue170006EPS3_ + 104
25  RealmEncryptionFailureTest          0x00000001047bc244 _ZNSt3__110unique_ptrIN5realm14WriteWindowMgr9MapWindowENS_14default_deleteIS3_EEED2B8ue170006Ev + 32
26  RealmEncryptionFailureTest          0x00000001047b15cc _ZNSt3__110unique_ptrIN5realm14WriteWindowMgr9MapWindowENS_14default_deleteIS3_EEED1B8ue170006Ev + 28
27  RealmEncryptionFailureTest          0x00000001047b9f34 _ZNSt3__19allocatorINS_10unique_ptrIN5realm14WriteWindowMgr9MapWindowENS_14default_deleteIS4_EEEEE7destroyB8ue170006EPS7_ + 28
28  RealmEncryptionFailureTest          0x00000001047b9ef8 _ZNSt3__116allocator_traitsINS_9allocatorINS_10unique_ptrIN5realm14WriteWindowMgr9MapWindowENS_14default_deleteIS5_EEEEEEE7destroyB8ue170006IS8_vEEvRS9_PT_ + 32
29  RealmEncryptionFailureTest          0x00000001047b9eb4 _ZNSt3__16vectorINS_10unique_ptrIN5realm14WriteWindowMgr9MapWindowENS_14default_deleteIS4_EEEENS_9allocatorIS7_EEE22__base_destruct_at_endB8ue170006EPS7_ + 104
30  RealmEncryptionFailureTest          0x00000001047b9cec _ZNSt3__16vectorINS_10unique_ptrIN5realm14WriteWindowMgr9MapWindowENS_14default_deleteIS4_EEEENS_9allocatorIS7_EEE7__clearB8ue170006Ev + 28
31  RealmEncryptionFailureTest          0x00000001047b9c5c _ZNSt3__16vectorINS_10unique_ptrIN5realm14WriteWindowMgr9MapWindowENS_14default_deleteIS4_EEEENS_9allocatorIS7_EEE16__destroy_vectorclB8ue170006Ev + 60
32  RealmEncryptionFailureTest          0x00000001047b9bd4 _ZNSt3__16vectorINS_10unique_ptrIN5realm14WriteWindowMgr9MapWindowENS_14default_deleteIS4_EEEENS_9allocatorIS7_EEED2B8ue170006Ev + 44
33  RealmEncryptionFailureTest          0x00000001047b0138 _ZNSt3__16vectorINS_10unique_ptrIN5realm14WriteWindowMgr9MapWindowENS_14default_deleteIS4_EEEENS_9allocatorIS7_EEED1B8ue170006Ev + 28
34  RealmEncryptionFailureTest          0x00000001047b6b70 _ZN5realm14WriteWindowMgrD2Ev + 32
35  RealmEncryptionFailureTest          0x00000001047b0284 _ZN5realm14WriteWindowMgrD1Ev + 28
36  RealmEncryptionFailureTest          0x00000001047b0d34 _ZN5realm11GroupWriterD2Ev + 144
37  RealmEncryptionFailureTest          0x00000001047b0d68 _ZN5realm11GroupWriterD1Ev + 28
38  RealmEncryptionFailureTest          0x000000010473b690 _ZN5realm2DB16low_level_commitEyRNS_11TransactionEb + 1696
39  RealmEncryptionFailureTest          0x000000010473ad80 _ZN5realm2DB9do_commitERNS_11TransactionEb + 300
40  RealmEncryptionFailureTest          0x0000000104e53918 _ZN5realm11Transaction27commit_and_continue_as_readEb + 208
41  RealmEncryptionFailureTest          0x0000000104948490 _ZN5realm5_impl16RealmCoordinator12commit_writeERNS_5RealmEb + 216
42  RealmEncryptionFailureTest          0x0000000104a0f8c4 _ZN5realm5Realm18commit_transactionEv + 268
43  RealmEncryptionFailureTest          0x00000001044990ac -[RLMRealm commitWriteTransactionWithoutNotifying:error:] + 556
44  RealmEncryptionFailureTest          0x00000001045f1844 $s10RealmSwift0A0V11commitWrite16withoutNotifyingySaySo20RLMNotificationTokenCG_tKF + 164
45  RealmEncryptionFailureTest          0x00000001045f15ac $s10RealmSwift0A0V5write16withoutNotifying_xSaySo20RLMNotificationTokenCG_xyKXEtKlF + 284
46  RealmEncryptionFailureTest          0x00000001041f5d90 $s26RealmEncryptionFailureTest9BaseModelC4saveyACXD0A5Swift0A0VKF + 148
47  RealmEncryptionFailureTest          0x00000001041f0ac4 $s26RealmEncryptionFailureTest7ActionsC15compactAndWriteyyKF + 836
48  RealmEncryptionFailureTest          0x00000001041ffdf4 $s26RealmEncryptionFailureTest11ContentViewV4bodyQrvg7SwiftUI05TupleF0VyAE0F0PAEE11buttonStyleyQrqd__AE015PrimitiveButtonL0Rd__lFQOyAE0N0VyAE4TextVG_AE08BorderednL0VQo__AStGyXEfU_yycfU0_ + 64
49  SwiftUI                             0x00000001bbf6fab4 E4A42961-DD73-3565-8CEC-A52571C86007 + 22944436
50  SwiftUI                             0x00000001bb6b7410 E4A42961-DD73-3565-8CEC-A52571C86007 + 13800464
51  SwiftUI                             0x00000001bb6bc174 E4A42961-DD73-3565-8CEC-A52571C86007 + 13820276
52  SwiftUI                             0x00000001bb6ba644 E4A42961-DD73-3565-8CEC-A52571C86007 + 13813316
53  SwiftUI                             0x00000001bb6ba598 E4A42961-DD73-3565-8CEC-A52571C86007 + 13813144
54  SwiftUI                             0x00000001bbc4f534 E4A42961-DD73-3565-8CEC-A52571C86007 + 19666228
55  SwiftUI                             0x00000001bbc4e9ac E4A42961-DD73-3565-8CEC-A52571C86007 + 19663276
56  SwiftUI                             0x00000001bbc4e4a8 E4A42961-DD73-3565-8CEC-A52571C86007 + 19661992
57  SwiftUI                             0x00000001bb845c04 E4A42961-DD73-3565-8CEC-A52571C86007 + 15432708
58  SwiftUI                             0x00000001bb845c20 E4A42961-DD73-3565-8CEC-A52571C86007 + 15432736
59  SwiftUI                             0x00000001bb845c04 E4A42961-DD73-3565-8CEC-A52571C86007 + 15432708
60  SwiftUI                             0x00000001bbf5d48c E4A42961-DD73-3565-8CEC-A52571C86007 + 22869132
61  SwiftUI                             0x00000001bbf5da70 E4A42961-DD73-3565-8CEC-A52571C86007 + 22870640
62  SwiftUI                             0x00000001bc0eb184 E4A42961-DD73-3565-8CEC-A52571C86007 + 24498564
63  SwiftUI                             0x00000001bbec12ac E4A42961-DD73-3565-8CEC-A52571C86007 + 22229676
64  SwiftUI                             0x00000001bbebf974 E4A42961-DD73-3565-8CEC-A52571C86007 + 22223220
65  SwiftUI                             0x00000001bbebfaac E4A42961-DD73-3565-8CEC-A52571C86007 + 22223532
66  UIKitCore                           0x00000001b914b9b0 EF33D746-33F2-33F7-A724-E25715D4B897 + 1395120
67  UIKitCore                           0x00000001b9014250 EF33D746-33F2-33F7-A724-E25715D4B897 + 119376
68  UIKitCore                           0x00000001b9010628 EF33D746-33F2-33F7-A724-E25715D4B897 + 103976
69  UIKitCore                           0x00000001b9010564 EF33D746-33F2-33F7-A724-E25715D4B897 + 103780
70  UIKitCore                           0x00000001b91e0988 EF33D746-33F2-33F7-A724-E25715D4B897 + 2005384
71  UIKitCore                           0x00000001b91dfc54 EF33D746-33F2-33F7-A724-E25715D4B897 + 2002004
72  UIKitCore                           0x00000001b91a52bc EF33D746-33F2-33F7-A724-E25715D4B897 + 1761980
73  UIKitCore                           0x00000001b91a37f4 EF33D746-33F2-33F7-A724-E25715D4B897 + 1755124
74  UIKitCore                           0x00000001b926bc80 EF33D746-33F2-33F7-A724-E25715D4B897 + 2575488
75  CoreFoundation                      0x00000001b6f062ec 1B48137D-6256-3164-9EC3-124F0AA34B77 + 217836
76  CoreFoundation                      0x00000001b6f055f4 1B48137D-6256-3164-9EC3-124F0AA34B77 + 214516
77  CoreFoundation                      0x00000001b6f03ee4 1B48137D-6256-3164-9EC3-124F0AA34B77 + 208612
78  CoreFoundation                      0x00000001b6f02b98 1B48137D-6256-3164-9EC3-124F0AA34B77 + 203672
79  CoreFoundation                      0x00000001b6f027a4 CFRunLoopRunSpecific + 572
80  GraphicsServices                    0x00000001f574e9fc GSEventRunModal + 160
81  UIKitCore                           0x00000001b9208a38 EF33D746-33F2-33F7-A724-E25715D4B897 + 2169400
82  UIKitCore                           0x00000001b92080a4 UIApplicationMain + 312
83  SwiftUI                             0x00000001bb84a970 E4A42961-DD73-3565-8CEC-A52571C86007 + 15452528
84  SwiftUI                             0x00000001bb84a800 E4A42961-DD73-3565-8CEC-A52571C86007 + 15452160
85  SwiftUI                             0x00000001bb5480fc E4A42961-DD73-3565-8CEC-A52571C86007 + 12296444
86  RealmEncryptionFailureTest          0x0000000104200b38 $s26RealmEncryptionFailureTest0abcD3AppV5$mainyyFZ + 40
87  RealmEncryptionFailureTest          0x0000000104200be8 main + 12
88  dyld                                0x00000001d79fd9c4 3B26AEFA-A8B4-36EB-A4C4-FDA1722CE8D9 + 22980
!!! IMPORTANT: Please report this at https://github.com/realm/realm-core/issues/new/choose
```
