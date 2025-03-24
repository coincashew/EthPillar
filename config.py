# MEV Relay Data
mainnet_relay_options = [
    {'name': 'Aestus', 'url': 'https://0xa15b52576bcbf1072f4a011c0f99f9fb6c66f3e1ff321f11f461d15e31b1cb359caa092c71bbded0bae5b5ea401aab7e@aestus.live'},
    {'name': 'Agnostic Gnosis', 'url': 'https://0xa7ab7a996c8584251c8f925da3170bdfd6ebc75d50f5ddc4050a6fdc77f2a3b5fce2cc750d0865e05d7228af97d69561@agnostic-relay.net'},
    {'name': 'bloXroute Max Profit', 'url': 'https://0x8b5d2e73e2a3a55c6c87b8b6eb92e0149a125c852751db1422fa951e42a09b82c142c3ea98d0d9930b056a3bc9896b8f@bloxroute.max-profit.blxrbdn.com'},
    {'name': 'bloXroute Regulated', 'url': 'https://0xb0b07cd0abef743db4260b0ed50619cf6ad4d82064cb4fbec9d3ec530f7c5e6793d9f286c4e082c0244ffb9f2658fe88@bloxroute.regulated.blxrbdn.com'},
    {'name': 'Flashbots', 'url': 'https://0xac6e77dfe25ecd6110b8e780608cce0dab71fdd5ebea22a16c0205200f2f8e2e3ad3b71d3499c54ad14d6c21b41a37ae@boost-relay.flashbots.net'},
    {'name': 'Ultra Sound', 'url': 'https://0xa1559ace749633b997cb3fdacffb890aeebdb0f5a3b6aaa7eeeaf1a38af0a8fe88b9e4b1f61f236d2e64d95733327a62@relay.ultrasound.money'}
]

holesky_relay_options = [
    {'name': 'Aestus', 'url': 'https://0xab78bf8c781c58078c3beb5710c57940874dd96aef2835e7742c866b4c7c0406754376c2c8285a36c630346aa5c5f833@holesky.aestus.live'},
    {'name': 'Ultra Sound', 'url': 'https://0xb1559beef7b5ba3127485bbbb090362d9f497ba64e177ee2c8e7db74746306efad687f2cf8574e38d70067d40ef136dc@relay-stag.ultrasound.money'},
    {'name': 'Flashbots', 'url': 'https://0xafa4c6985aa049fb79dd37010438cfebeb0f2bd42b115b89dd678dab0670c1de38da0c4e9138c9290a398ecd9a0b3110@boost-relay-holesky.flashbots.net'},
    {'name': 'bloXroute', 'url': 'https://0x821f2a65afb70e7f2e820a925a9b4c80a159620582c1766b1b09729fec178b11ea22abb3a51f07b288be815a1a2ff516@bloxroute.holesky.blxrbdn.com'},
    {'name': 'Eden Network', 'url': 'https://0xb1d229d9c21298a87846c7022ebeef277dfc321fe674fa45312e20b5b6c400bfde9383f801848d7837ed5fc449083a12@relay-holesky.edennetwork.io'},
    {'name': 'Titan Relay', 'url': 'https://0xaa58208899c6105603b74396734a6263cc7d947f444f396a90f7b7d3e65d102aec7e5e5291b27e08d02c50a050825c2f@holesky.titanrelay.xyz'}
]

sepolia_relay_options = [
    {'name': 'Flashbots', 'url': 'https://0x845bd072b7cd566f02faeb0a4033ce9399e42839ced64e8b2adcfc859ed1e8e1a5a293336a49feac6d9a5edb779be53a@boost-relay-sepolia.flashbots.net'}
]

hoodi_relay_options = [
    {'name': 'Titan Relay', 'url': 'https://0xaa58208899c6105603b74396734a6263cc7d947f444f396a90f7b7d3e65d102aec7e5e5291b27e08d02c50a050825c2f@hoodi.titanrelay.xyz'}
]

# Checkpoint-Sync Data
mainnet_sync_urls = [
    ("ETHSTAKER", "https://beaconstate.ethstaker.cc"),
    ("BEACONCHA.IN", "https://sync-mainnet.beaconcha.in"),
    ("ATTESTANT", "https://mainnet-checkpoint-sync.attestant.io"),
    ("SIGMA PRIME", "https://mainnet.checkpoint.sigp.io"),
    ("Lodestar", "https://beaconstate-mainnet.chainsafe.io"),
    ("BeaconState.info", "https://beaconstate.info"),
    ("PietjePuk", "https://checkpointz.pietjepuk.net"),
    ("invistools", "https://sync.invis.tools"),
    ("Nimbus", "http://testing.mainnet.beacon-api.nimbus.team"),
]

holesky_sync_urls = [
    ("ETHSTAKER", "https://holesky.beaconstate.ethstaker.cc"),
    ("BEACONSTATE", "https://holesky.beaconstate.info"),
    ("EF DevOps", "https://checkpoint-sync.holesky.ethpandaops.io"),
    ("Lodestar", "https://beaconstate-holesky.chainsafe.io"),
]

sepolia_sync_urls = [
    ("Beaconstate", "https://sepolia.beaconstate.info"),
    ("Lodestar", "https://beaconstate-sepolia.chainsafe.io"),
    ("EF DevOps", "https://checkpoint-sync.sepolia.ethpandaops.io"),
]

ephemery_sync_urls = [
    ("ETHSTAKER", "https://ephemery.beaconstate.ethstaker.cc"),
    ("EF DevOps", "https://checkpoint-sync.ephemery.ethpandaops.io"),
]

hoodi_sync_urls = [
    ("EF DevOps", "https://checkpoint-sync.hoodi.ethpandaops.io"),
    ("ATTESTANT", "https://hoodi-checkpoint-sync.attestant.io"),
]