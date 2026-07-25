// Curated, offline IUCN Red List reference data for the "Threat Level" field
// on the researcher submission form. This is NOT a live mirror of
// iucnredlist.org (their site blocks automated bulk scraping and the
// Orchidaceae list runs to tens of thousands of taxa, most of which are
// irrelevant to this project). Instead it bundles:
//   1) The official IUCN Red List Category definitions/criteria (version 3.1),
//      which apply to every species regardless of genus.
//   2) A hand-picked set of real, published orchid assessments -- weighted
//      toward Philippine/Southeast Asian species relevant to field work here --
//      to use as reference points when a specimen has no exact IUCN match
//      (which is expected: most morphospecies logged in this app, e.g.
//      "Appendicula sp. 1", are undescribed and have never been assessed).
// Compiled July 2026 from iucnredlist.org species accounts, IUCN SSC
// Orchid Specialist Group publications, and Kew POWO / peer-reviewed
// sources cited per record below. Cross-check iucnredlist.org directly
// before treating any single figure as authoritative for a publication.

window.IUCN_RED_LIST_CATEGORIES = [
  {
    code: 'CR',
    label: 'Critically Endangered',
    color: '#b91c1c',
    bg: '#fef2f2',
    definition: 'Facing an extremely high risk of extinction in the wild.',
    criteria: 'Meets any of: population decline ≥90% over 10 years/3 generations; fewer than 250 mature individuals with continuing decline; extent of occurrence < 100 km² or area of occupancy < 10 km² with severe fragmentation/decline; or a quantitative analysis showing ≥50% extinction probability within 10 years/3 generations.'
  },
  {
    code: 'EN',
    label: 'Endangered',
    color: '#c2410c',
    bg: '#fff7ed',
    definition: 'Facing a very high risk of extinction in the wild.',
    criteria: 'Meets any of: population decline ≥70% over 10 years/3 generations; fewer than 2,500 mature individuals with continuing decline; extent of occurrence < 5,000 km² or area of occupancy < 500 km² with severe fragmentation/decline; or ≥20% extinction probability within 20 years/5 generations.'
  },
  {
    code: 'VU',
    label: 'Vulnerable',
    color: '#a16207',
    bg: '#fefce8',
    definition: 'Facing a high risk of extinction in the wild.',
    criteria: 'Meets any of: population decline ≥50% over 10 years/3 generations; fewer than 10,000 mature individuals with continuing decline; extent of occurrence < 20,000 km² or area of occupancy < 2,000 km² with severe fragmentation/decline; or ≥10% extinction probability within 100 years.'
  },
  {
    code: 'NT',
    label: 'Near Threatened',
    color: '#4d7c0f',
    bg: '#f7fee7',
    definition: 'Close to qualifying for, or likely to qualify for, a threatened category in the near future.',
    criteria: 'Evaluated against the criteria but does not currently qualify for CR, EN or VU -- typically shown by a declining trend, a small/restricted range, or dependence on a conservation programme.'
  },
  {
    code: 'LC',
    label: 'Least Concern',
    color: '#15803d',
    bg: '#f0fdf4',
    definition: 'Widespread and abundant taxa that do not qualify for a more threatened category.',
    criteria: 'Evaluated and found not to qualify for CR, EN, VU or NT. Note: "Least Concern" is a formal, evaluated status -- it is not the same as "never assessed."'
  },
  {
    code: 'DD',
    label: 'Data Deficient',
    color: '#475569',
    bg: '#f8fafc',
    definition: 'Not enough information to make a direct or indirect assessment of extinction risk.',
    criteria: 'The taxon has been evaluated, but available data on distribution and/or population status are inadequate to assign any other category. This is not a threatened category -- it flags a research gap.'
  },
  {
    code: 'NE',
    label: 'Not Evaluated',
    color: '#64748b',
    bg: '#f8fafc',
    definition: 'Has not yet been assessed against the criteria at all.',
    criteria: 'The overwhelming majority of described orchid species -- and essentially all undescribed field morphospecies ("sp.", "cf.", "aff." entries) -- fall here simply because no assessor has evaluated them yet. This is the default status for a newly logged or unidentified specimen.'
  }
];

// sci: scientific name | common: common name | genus | category: code from
// IUCN_RED_LIST_CATEGORIES above | region: known range | threats: primary
// pressures reported | source: where this was compiled from.
window.IUCN_ORCHID_REFERENCE = [
  {
    sci: 'Paphiopedilum rothschildianum',
    common: "Rothschild's Slipper Orchid",
    genus: 'Paphiopedilum',
    category: 'CR',
    region: 'Borneo (Sabah, Malaysia -- Mt. Kinabalu area)',
    threats: 'Illegal collection for horticultural trade, habitat disturbance',
    source: 'IUCN Red List species assessment'
  },
  {
    sci: 'Paphiopedilum sanderianum',
    common: "Sander's Slipper Orchid",
    genus: 'Paphiopedilum',
    category: 'CR',
    region: 'Borneo (Sarawak, Malaysia)',
    threats: 'Collection (extremely prized long-petalled species, very restricted cliff habitat)',
    source: 'IUCN Red List species assessment; Wikipedia summary'
  },
  {
    sci: 'Paphiopedilum gratrixianum',
    common: "Gratrix's Slipper Orchid",
    genus: 'Paphiopedilum',
    category: 'CR',
    region: 'Indochina (Laos, Vietnam, Thailand)',
    threats: 'Collection, fragmented and shrinking habitat',
    source: 'IUCN Red List species assessment'
  },
  {
    sci: 'Paphiopedilum urbanianum',
    common: 'Urban’s Slipper Orchid',
    genus: 'Paphiopedilum',
    category: 'CR',
    region: 'Philippines (endemic)',
    threats: 'Collection, land conversion',
    source: 'IUCN Red List species assessment; Wikipedia'
  },
  {
    sci: 'Paphiopedilum stonei',
    common: "Stone's Slipper Orchid",
    genus: 'Paphiopedilum',
    category: 'CR',
    region: 'Borneo (Sarawak, Malaysia)',
    threats: 'Collection for horticultural trade',
    source: 'IUCN Red List species assessment; Wikipedia'
  },
  {
    sci: 'Paphiopedilum victoriae-reginae',
    common: 'Queen Victoria’s Slipper Orchid',
    genus: 'Paphiopedilum',
    category: 'CR',
    region: 'Sumatra, Indonesia',
    threats: 'Collection, narrow limestone-cliff range',
    source: 'IUCN Red List species assessment'
  },
  {
    sci: 'Vanda scandens',
    common: 'Climbing Vanda',
    genus: 'Vanda',
    category: 'EN',
    region: 'Philippines (endemic -- Mindanao, Palawan)',
    threats: 'Habitat loss (logging, land conversion), collection',
    source: 'IUCN Red List species assessment; Wikipedia'
  },
  {
    sci: 'Vanda javierae',
    common: "Javier's Vanda",
    genus: 'Vanda',
    category: 'EN',
    region: 'Philippines (endemic -- Luzon, Calayan Island)',
    threats: 'Habitat loss, collection',
    source: 'IUCN Red List species assessment; Wikipedia'
  },
  {
    sci: 'Vanda coerulea',
    common: 'Blue Vanda',
    genus: 'Vanda',
    category: 'VU',
    region: 'NE India, Myanmar, Thailand, S. China (Yunnan)',
    threats: 'Overcollection (prized blue flowers), habitat loss; CITES Appendix II',
    source: 'IUCN Red List species assessment'
  },
  {
    sci: 'Dendrobium schuetzei',
    common: "Schuetze's Dendrobium",
    genus: 'Dendrobium',
    category: 'CR',
    region: 'Philippines (endemic -- NE Mindanao)',
    threats: 'Habitat loss, unsustainable wild harvesting',
    source: 'IUCN Red List species assessment; Wikipedia'
  },
  {
    sci: 'Dendrobium sanderae',
    common: "Sander's Dendrobium",
    genus: 'Dendrobium',
    category: 'VU',
    region: 'Philippines (endemic)',
    threats: 'Collection, habitat loss',
    source: 'IUCN Red List species assessment; Wikipedia'
  },
  {
    sci: 'Phalaenopsis lindenii',
    common: "Linden's Phalaenopsis",
    genus: 'Phalaenopsis',
    category: 'EN',
    region: 'Philippines (endemic -- Luzon)',
    threats: 'Habitat loss, collection',
    source: 'IUCN Red List species assessment; Wikipedia'
  },
  {
    sci: 'Phalaenopsis micholitzii',
    common: "Micholitz's Phalaenopsis",
    genus: 'Phalaenopsis',
    category: 'CR',
    region: 'Philippines (a handful of known sites)',
    threats: 'Collection, habitat loss',
    source: 'IUCN Red List species assessment; Wikipedia'
  },
  {
    sci: 'Renanthera imschootiana',
    common: 'Red Vanda',
    genus: 'Renanthera',
    category: 'EN',
    region: 'NE India, Myanmar, S. China, Vietnam',
    threats: 'Heavy collection for its red flowers, habitat loss; CITES Appendix I',
    source: 'IUCN Red List species assessment'
  },
  {
    sci: 'Cypripedium calceolus',
    common: "Lady's Slipper Orchid",
    genus: 'Cypripedium',
    category: 'LC',
    region: 'Europe and temperate Asia',
    threats: 'Historically overcollected; globally secure but nationally protected/declining in several countries',
    source: 'IUCN Red List species assessment -- a useful example of a global LC status masking serious regional decline'
  },
  {
    sci: 'Epipactis helleborine',
    common: 'Broad-leaved Helleborine',
    genus: 'Epipactis',
    category: 'LC',
    region: 'Europe, temperate Asia; naturalized in North America',
    threats: 'None significant; widespread and locally weedy',
    source: 'IUCN Red List species assessment'
  },
  {
    sci: 'Spathoglottis plicata',
    common: 'Philippine Ground Orchid',
    genus: 'Spathoglottis',
    category: 'NE',
    region: 'Widespread SE Asia and the Pacific, incl. Philippines',
    threats: 'None known; common and widely cultivated',
    source: 'Not yet assessed on the IUCN Red List -- included to show that "common" and "Least Concern" are not the same thing until a formal assessment exists'
  },
  {
    sci: 'Grammatophyllum speciosum',
    common: 'Tiger Orchid (world’s largest orchid)',
    genus: 'Grammatophyllum',
    category: 'NE',
    region: 'SE Asia incl. Philippines',
    threats: 'Collection as an ornamental in parts of its range',
    source: 'Not yet independently assessed on the IUCN Red List'
  }
];
