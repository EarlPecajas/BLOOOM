// Official reference data for the "Threat Level" field on the researcher
// submission form, sourced directly from DENR Administrative Order No.
// 2026-20, "Updated National List of Threatened Philippine Plants and
// Their Categories" (Sec. 4.9, Sec. 4.13, Sec. 6). This replaces the
// earlier IUCN Red List-based reference now that DAO 2026-20 is the
// governing classification used for Philippine orchid conservation status
// in this app.
//   1) Category definitions are taken verbatim from DAO 2026-20 Sec. 4.13
//      (plus Sec. 4.9/Sec. 7 for the "Not Listed" / Other Wildlife Species
//      status used when a species isn't in the DAO 2026-20 list at all).
//   2) Every Orchidaceae entry in DAO 2026-20 Sec. 6 is included -- all 108
//      species across Categories A (Critically Endangered), B (Endangered),
//      C (Vulnerable), and D (Other Threatened Species).
// Compiled July 2026 from DAO 2026-20 (DENR Administrative Order, published
// The Manila Times, April 16 2026; effective 15 days after publication).

window.DAO_2026_20_CATEGORIES = [
  {
    code: 'CR',
    label: 'Critically Endangered',
    color: '#b91c1c',
    bg: '#fef2f2',
    definition: 'A species, subspecies, variety, or other infraspecific categories facing extremely high risk of extinction in the wild in the immediate future.',
    criteria: 'DAO 2026-20, Sec. 4.13.1.'
  },
  {
    code: 'EN',
    label: 'Endangered',
    color: '#c2410c',
    bg: '#fff7ed',
    definition: 'A species, subspecies, variety, or forma that is not critically endangered but whose survival in the wild is unlikely if the causal factors continue operating.',
    criteria: 'DAO 2026-20, Sec. 4.13.2.'
  },
  {
    code: 'VU',
    label: 'Vulnerable',
    color: '#a16207',
    bg: '#fefce8',
    definition: 'A species or subspecies, variety, forma or other infraspecific categories of plant that is not critically endangered nor endangered but is under threat from adverse factors throughout its range and is likely to move to the endangered category in the future.',
    criteria: 'DAO 2026-20, Sec. 4.13.3.'
  },
  {
    code: 'OTS',
    label: 'Other Threatened Species',
    color: '#6d28d9',
    bg: '#f5f3ff',
    definition: 'A species, subspecies, varieties, or other infraspecific categories that is not critically endangered, endangered nor vulnerable but is under threat from adverse factors, such as over collection throughout its range, and is likely to move to the vulnerable category in the near future.',
    criteria: 'DAO 2026-20, Sec. 4.13.4.'
  },
  {
    code: 'NL',
    label: 'Not Listed',
    color: '#475569',
    bg: '#f8fafc',
    definition: 'Not included in the DAO 2026-20 threatened plant list -- treated as an Other Wildlife Species (OWS).',
    criteria: 'DAO 2026-20, Sec. 4.9 / Sec. 7. Absence from the list is not a formal safety assessment; it means DENR has not placed this species in a threatened category.'
  }
];

// sci: clean binomial ("Genus species") used for matching against the
// submission form's Scientific Name field | fullName: the exact name with
// authorship as printed in DAO 2026-20 | common: common/local name as
// printed (empty string where DAO 2026-20 gives none) | genus | category:
// code from DAO_2026_20_CATEGORIES | endemic: true where DAO 2026-20 marks
// the species with the endemism asterisk | source.
window.DAO_2026_20_ORCHID_REFERENCE = [
  // -- Category A: Critically Endangered (32) ---------------------------
  { sci: 'Amesiella monticola', fullName: 'Amesiella monticola Cootes & D.P.Banks', common: 'montane amesiella', genus: 'Amesiella', category: 'CR', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Bulbophyllum cootesii', fullName: 'Bulbophyllum cootesii M.A.Clem.', common: 'Cootes bulbophyllum', genus: 'Bulbophyllum', category: 'CR', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Ceratocentron fesselii', fullName: 'Ceratocentron fesselii Senghas', common: 'Fessel horned orchid', genus: 'Ceratocentron', category: 'CR', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Corybas boholensis', fullName: 'Corybas boholensis Tandang, R.Bustam., T.Reyes Jr. & S.P.Lyon', common: 'Bohol helmet orchid', genus: 'Corybas', category: 'CR', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Corybas hamiguitanensis', fullName: 'Corybas hamiguitanensis Tandang, Galindon & R.Bustam.', common: 'Hamiguitan helmet orchid', genus: 'Corybas', category: 'CR', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Corybas kaiganganianus', fullName: 'Corybas kaiganganianus Tandang, A.S.Rob. & M.D.Angeles', common: 'limestone helmet orchid', genus: 'Corybas', category: 'CR', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Dendrobium schuetzei', fullName: 'Dendrobium schuetzei Rolfe', common: 'Scheutze sanggumay', genus: 'Dendrobium', category: 'CR', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Gastrochilus calceolaris', fullName: 'Gastrochilus calceolaris (Buch.-Ham. ex Sm.) D.Don', common: '', genus: 'Gastrochilus', category: 'CR', endemic: false, source: 'DAO 2026-20' },
  { sci: 'Grammatophyllum ravanii', fullName: 'Grammatophyllum ravanii D.Tiu', common: 'Ravan giant orchid', genus: 'Grammatophyllum', category: 'CR', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Grammatophyllum speciosum', fullName: 'Grammatophyllum speciosum Blume', common: 'malatubo, giant orchid', genus: 'Grammatophyllum', category: 'CR', endemic: false, source: 'DAO 2026-20' },
  { sci: 'Grammatophyllum wallisii', fullName: 'Grammatophyllum wallisii Rchb.f', common: 'Wallis giant orchid', genus: 'Grammatophyllum', category: 'CR', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Mycaranthes leonardoi', fullName: 'Mycaranthes leonardoi Ferreras & Suarez', common: 'Leonardo mycaranthes', genus: 'Mycaranthes', category: 'CR', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Paphiopedilum acmodontum', fullName: 'Paphiopedilum acmodontum Schoser ex M.W.Wood', common: 'pointed-tooth lady slipper orchid', genus: 'Paphiopedilum', category: 'CR', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Paphiopedilum adductum', fullName: 'Paphiopedilum adductum Asher', common: 'Mindanao lady slipper orchid', genus: 'Paphiopedilum', category: 'CR', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Paphiopedilum argus', fullName: 'Paphiopedilum argus (Rchb.f.) Stein', common: 'spotted-petal lady slipper orchid', genus: 'Paphiopedilum', category: 'CR', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Paphiopedilum barbatum', fullName: 'Paphiopedilum barbatum (Lindl.) Pfitzer', common: 'bearded lady slipper orchid', genus: 'Paphiopedilum', category: 'CR', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Paphiopedilum ciliolare', fullName: 'Paphiopedilum ciliolare (Rchb.f.) Stein', common: 'short-haired lady slipper orchid', genus: 'Paphiopedilum', category: 'CR', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Paphiopedilum fowliei', fullName: 'Paphiopedilum fowliei Birk', common: 'Fowlie lady slipper orchid', genus: 'Paphiopedilum', category: 'CR', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Paphiopedilum haynaldianum', fullName: 'Paphiopedilum haynaldianum (Rchb.f.) Stein', common: 'Haynald lady slipper orchid', genus: 'Paphiopedilum', category: 'CR', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Paphiopedilum hennisianum', fullName: 'Paphiopedilum hennisianum (M.W.Wood) Fowlie', common: 'Hennis lady slipper orchid', genus: 'Paphiopedilum', category: 'CR', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Paphiopedilum lowii', fullName: 'Paphiopedilum lowii (Lindl.) Stein.', common: 'Low lady slipper orchid', genus: 'Paphiopedilum', category: 'CR', endemic: false, source: 'DAO 2026-20' },
  { sci: 'Paphiopedilum parnatanum', fullName: 'Paphiopedilum parnatanum Cavestro', common: "Parnata's lady slipper orchid", genus: 'Paphiopedilum', category: 'CR', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Paphiopedilum philippinense', fullName: 'Paphiopedilum philippinense (Rchb.f.) Stein', common: 'Philippine lady slipper orchid', genus: 'Paphiopedilum', category: 'CR', endemic: false, source: 'DAO 2026-20' },
  { sci: 'Paphiopedilum randsii', fullName: 'Paphiopedilum randsii Fowlie', common: 'Rands lady slipper orchid', genus: 'Paphiopedilum', category: 'CR', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Paphiopedilum urbanianum', fullName: 'Paphiopedilum urbanianum Fowlie', common: 'Urban lady slipper orchid', genus: 'Paphiopedilum', category: 'CR', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Phalaenopsis micholitzii', fullName: 'Phalaenopsis micholitzii Rolfe', common: 'Micholitz moth orchid', genus: 'Phalaenopsis', category: 'CR', endemic: false, source: 'DAO 2026-20' },
  { sci: 'Phragmorchis teretifolia', fullName: 'Phragmorchis teretifolia L.O.Williams', common: '', genus: 'Phragmorchis', category: 'CR', endemic: false, source: 'DAO 2026-20' },
  { sci: 'Renanthera caloptera', fullName: 'Renanthera caloptera (Rchb.f.) Kocyan & Schult.', common: '', genus: 'Renanthera', category: 'CR', endemic: false, source: 'DAO 2026-20' },
  { sci: 'Stigmatodactylus aquamarinus', fullName: 'Stigmatodactylus aquamarinus A.S.Rob. & Gironella', common: '', genus: 'Stigmatodactylus', category: 'CR', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Stigmatodactylus dalagangpalawanicum', fullName: 'Stigmatodactylus dalagangpalawanicum A.S.Rob', common: '', genus: 'Stigmatodactylus', category: 'CR', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Vanda lamellata', fullName: 'Vanda lamellata Lindl.', common: 'bo-o', genus: 'Vanda', category: 'CR', endemic: false, source: 'DAO 2026-20' },
  { sci: 'Vanda sanderiana', fullName: 'Vanda sanderiana Rchb.f.', common: 'waling-waling', genus: 'Vanda', category: 'CR', endemic: true, source: 'DAO 2026-20' },

  // -- Category B: Endangered (48) ---------------------------------------
  { sci: 'Amesiella philippinensis', fullName: 'Amesiella philippinensis (Ames) Garay', common: 'Philippine amesiella', genus: 'Amesiella', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Aerides lawrenceae', fullName: 'Aerides lawrenceae Rchb.f.', common: "Lawrence cat's tail orchid", genus: 'Aerides', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Arachnis flos-aeris', fullName: 'Arachnis flos-aeris (L.) Rchb.f.', common: 'scorpion orchid', genus: 'Arachnis', category: 'EN', endemic: false, source: 'DAO 2026-20' },
  { sci: 'Bulbophyllum cumingii', fullName: 'Bulbophyllum cumingii (Lindl.) Rchb.f.', common: 'Cuming bulbophyllum', genus: 'Bulbophyllum', category: 'EN', endemic: false, source: 'DAO 2026-20' },
  { sci: 'Bulbophyllum facetum', fullName: 'Bulbophyllum facetum Garay, Hamer & Siegerist', common: '', genus: 'Bulbophyllum', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Bulbophyllum loherianum', fullName: 'Bulbophyllum loherianum (Kraenzl.) Ames', common: 'Loher bulbophyllum', genus: 'Bulbophyllum', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Bulbophyllum piestoglossum', fullName: 'Bulbophyllum piestoglossum J.J.Verm.', common: '', genus: 'Bulbophyllum', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Bulbophyllum nymphopolitanum', fullName: 'Bulbophyllum nymphopolitanum Kraenzl.', common: '', genus: 'Bulbophyllum', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Bulbophyllum savaiense', fullName: 'Bulbophyllum savaiense Schltr. ssp. subcubicum (J.J.Sm.) J.J.Verm.', common: '', genus: 'Bulbophyllum', category: 'EN', endemic: false, source: 'DAO 2026-20' },
  { sci: 'Bulbophyllum stellatum', fullName: 'Bulbophyllum stellatum Ames', common: '', genus: 'Bulbophyllum', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Cleisostoma sagittatum', fullName: 'Cleisostoma sagittatum Blume', common: '', genus: 'Cleisostoma', category: 'EN', endemic: false, source: 'DAO 2026-20' },
  { sci: 'Coelogyne confusa', fullName: 'Coelogyne confusa Ames', common: '', genus: 'Coelogyne', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Coelogyne palawanensis', fullName: 'Coelogyne palawanensis Ames', common: 'Palawan coelogyne', genus: 'Coelogyne', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Corybas circinatus', fullName: 'Corybas circinatus Tandang & R.Bustam.', common: 'Palawan helmet orchid', genus: 'Corybas', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Corybas laceratus', fullName: 'Corybas laceratus L.O.Williams', common: 'saw-toothed helmet orchid', genus: 'Corybas', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Corybas merrillii', fullName: 'Corybas merrillii (Ames) Ames', common: 'Merrill helmet orchid', genus: 'Corybas', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Corybas ramosianus', fullName: 'Corybas ramosianus J.Dransf.', common: 'Ramos helmet orchid', genus: 'Corybas', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Cylindrolobus oliviacamposiae', fullName: 'Cylindrolobus oliviacamposiae Naive, Mabanta & Cootes', common: '', genus: 'Cylindrolobus', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Cymbidium aliciae', fullName: 'Cymbidium aliciae Quisumb.', common: '', genus: 'Cymbidium', category: 'EN', endemic: false, source: 'DAO 2026-20' },
  { sci: 'Cymbidium ensifolium', fullName: 'Cymbidium ensifolium (L.) Sw.', common: '', genus: 'Cymbidium', category: 'EN', endemic: false, source: 'DAO 2026-20' },
  { sci: 'Dendrobium bullenianum', fullName: 'Dendrobium bullenianum Rchb.f', common: 'Bullen dendrobium', genus: 'Dendrobium', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Dendrobium goldschmidtianum', fullName: 'Dendrobium goldschmidtianum Kraenzl.', common: 'Goldschmidt dendrobium', genus: 'Dendrobium', category: 'EN', endemic: false, source: 'DAO 2026-20' },
  { sci: 'Dendrobium lunatum', fullName: 'Dendrobium lunatum Lindl.', common: 'Moonlight dendrobium', genus: 'Dendrobium', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Dendrochilum kopfii', fullName: 'Dendrochilum kopfii Luckel', common: 'Kopf dendrochilum', genus: 'Dendrochilum', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Grammatophyllum martae', fullName: 'Grammatophyllum martae Quisumb. ex Valmayor & D.Tiu', common: 'Marta dapugay', genus: 'Grammatophyllum', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Grammatophyllum measuresianum', fullName: 'Grammatophyllum measuresianum Sander', common: 'Measures dapugay', genus: 'Grammatophyllum', category: 'EN', endemic: false, source: 'DAO 2026-20' },
  { sci: 'Phalaenopsis amabilis', fullName: 'Phalaenopsis amabilis (L.) Blume', common: 'mariposa', genus: 'Phalaenopsis', category: 'EN', endemic: false, source: 'DAO 2026-20' },
  { sci: 'Phalaenopsis hieroglyphica', fullName: 'Phalaenopsis hieroglyphica (Rchb.f.) H.R.Sweet', common: 'hieroglyphic moth orchid', genus: 'Phalaenopsis', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Phalaenopsis lindenii', fullName: 'Phalaenopsis lindenii Loher', common: 'Linden moth orchid', genus: 'Phalaenopsis', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Phalaenopsis lueddemanniana', fullName: 'Phalaenopsis lueddemanniana Rchb.f.', common: 'Lueddemann moth orchid', genus: 'Phalaenopsis', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Phalaenopsis pallens', fullName: 'Phalaenopsis pallens (Lindl.) Rchb.f.', common: 'pale moth orchid', genus: 'Phalaenopsis', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Phalaenopsis philippinensis', fullName: 'Phalaenopsis philippinensis Golamco ex Fowlie & C.Z.Tsang', common: 'Philippine moth orchid', genus: 'Phalaenopsis', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Phalaenopsis pulchra', fullName: 'Phalaenopsis pulchra (Rchb.f.) H.R.Sweet', common: 'beautiful moth orchid', genus: 'Phalaenopsis', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Phalaenopsis reichenbachiana', fullName: 'Phalaenopsis reichenbachiana Rchb.f. & Sander', common: 'Reichenbach moth orchid', genus: 'Phalaenopsis', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Phalaenopsis sanderiana', fullName: 'Phalaenopsis sanderiana Rchb.f.', common: 'Sander moth orchid', genus: 'Phalaenopsis', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Phalaenopsis schilleriana', fullName: 'Phalaenopsis schilleriana Rchb.f.', common: 'Schiller moth orchid', genus: 'Phalaenopsis', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Phalaenopsis stuartiana', fullName: 'Phalaenopsis stuartiana Rchb.f.', common: 'Stuart moth orchid', genus: 'Phalaenopsis', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Pseuderia samarana', fullName: 'Pseuderia samarana Z.D.Meneses & Cootes', common: '', genus: 'Pseuderia', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Renanthera monachica', fullName: 'Renanthera monachica Ames', common: 'dancing lady fire orchid', genus: 'Renanthera', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Renanthera philippinensis', fullName: 'Renanthera philippinensis (Ames & Quisumb.) L.O.Williams', common: 'Philippine fire orchid', genus: 'Renanthera', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Renanthera storiei', fullName: 'Renanthera storiei Rchb.f.', common: 'Storie fire orchid', genus: 'Renanthera', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Trichoglottis fasciata', fullName: 'Trichoglottis fasciata Rchb.f.', common: 'hairy-lipped orchid', genus: 'Trichoglottis', category: 'EN', endemic: false, source: 'DAO 2026-20' },
  { sci: 'Trichoglottis loheriana', fullName: 'Trichoglottis loheriana (Kraenzl.) L.O.Williams', common: 'Loher hairy-lipped orchid', genus: 'Trichoglottis', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Trichoglottis luzonensis', fullName: 'Trichoglottis luzonensis (Ames) Ames', common: 'Luzon hairy-lipped orchid', genus: 'Trichoglottis', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Vanda javierae', fullName: 'Vanda javierae D.Tiu ex Fessel & Luckel', common: 'Javier vanda', genus: 'Vanda', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Vanda luzonica', fullName: 'Vanda luzonica Loher ex Rolfe', common: 'Luzon vanda', genus: 'Vanda', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Vanda merrillii', fullName: 'Vanda merrillii Ames & Quisumb.', common: 'Merrill vanda', genus: 'Vanda', category: 'EN', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Vanda scandens', fullName: 'Vanda scandens Holttum', common: 'climbing vanda', genus: 'Vanda', category: 'EN', endemic: false, source: 'DAO 2026-20' },

  // -- Category C: Vulnerable (27) ----------------------------------------
  { sci: 'Aerides leeana', fullName: 'Aerides leeana Rchb.f.', common: '', genus: 'Aerides', category: 'VU', endemic: false, source: 'DAO 2026-20' },
  { sci: 'Aerides quinquevulnera', fullName: 'Aerides quinquevulnera Lindl.', common: 'five-wound aerides', genus: 'Aerides', category: 'VU', endemic: false, source: 'DAO 2026-20' },
  { sci: 'Blepharoglossum palawanense', fullName: 'Blepharoglossum palawanense (Ames) L.Li', common: '', genus: 'Blepharoglossum', category: 'VU', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Bulbophyllum curranii', fullName: 'Bulbophyllum curranii Ames', common: 'Curran bulbophyllum', genus: 'Bulbophyllum', category: 'VU', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Bulbophyllum papulosum', fullName: 'Bulbophyllum papulosum Garay', common: '', genus: 'Bulbophyllum', category: 'VU', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Cymboglossum palawanense', fullName: 'Cymboglossum palawanense (Ames) Ormerod & Cootes', common: '', genus: 'Cymboglossum', category: 'VU', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Dendrobium nemorale', fullName: 'Dendrobium nemorale L.O.Williams', common: '', genus: 'Dendrobium', category: 'VU', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Dendrobium sanderae', fullName: 'Dendrobium sanderae Rolfe', common: 'Sander dendrobium', genus: 'Dendrobium', category: 'VU', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Dendrobium secundum', fullName: 'Dendrobium secundum (Blume) Lindl. ex Wall.', common: '', genus: 'Dendrobium', category: 'VU', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Dendrobium usterioides', fullName: 'Dendrobium usterioides Ames', common: '', genus: 'Dendrobium', category: 'VU', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Dendrobium victoria-reginae', fullName: 'Dendrobium victoria-reginae Loher', common: 'Queen Victoria dendrobium', genus: 'Dendrobium', category: 'VU', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Dendrochilum ignisiflorum', fullName: 'Dendrochilum ignisiflorum M.N.Tamayo & R.Bustam.', common: 'fire dendrochilum', genus: 'Dendrochilum', category: 'VU', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Dendrochilum kingii', fullName: 'Dendrochilum kingii (Hook.f.) J.J.Sm.', common: 'King dendrochilum', genus: 'Dendrochilum', category: 'VU', endemic: false, source: 'DAO 2026-20' },
  { sci: 'Dilochia deleoniae', fullName: 'Dilochia deleoniae Tandang & Galindon', common: 'De Leon ground orchid', genus: 'Dilochia', category: 'VU', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Epigeneium stella-silvae', fullName: 'Epigeneium stella-silvae (Loher & Kraenzl.) Summerh.', common: 'Stella Silva epigeneium', genus: 'Epigeneium', category: 'VU', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Epigeneium treacherianum', fullName: 'Epigeneium treacherianum (Rchb.f ex Hook.f.) Summerh.', common: '', genus: 'Epigeneium', category: 'VU', endemic: false, source: 'DAO 2026-20' },
  { sci: 'Grammatophyllum multiflorum', fullName: 'Grammatophyllum multiflorum Lindl.', common: 'rosa mia', genus: 'Grammatophyllum', category: 'VU', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Grammatophyllum scriptum', fullName: 'Grammatophyllum scriptum (L.) Blume', common: 'dapugay', genus: 'Grammatophyllum', category: 'VU', endemic: false, source: 'DAO 2026-20' },
  { sci: 'Phalaenopsis aphrodite', fullName: 'Phalaenopsis aphrodite Rchb.f', common: 'aphrodite moth orchid', genus: 'Phalaenopsis', category: 'VU', endemic: false, source: 'DAO 2026-20' },
  { sci: 'Phalaenopsis bastianii', fullName: 'Phalaenopsis bastianii O.Gruss & Roellke', common: 'mariposa', genus: 'Phalaenopsis', category: 'VU', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Phalaenopsis cornu-cervi', fullName: 'Phalaenopsis cornu-cervi (Breda) Blume & Rchb.f.', common: "deer's horn moth orchid", genus: 'Phalaenopsis', category: 'VU', endemic: false, source: 'DAO 2026-20' },
  { sci: 'Phalaenopsis equestris', fullName: 'Phalaenopsis equestris (Schauer) Rchb.f', common: 'moth orchid', genus: 'Phalaenopsis', category: 'VU', endemic: false, source: 'DAO 2026-20' },
  { sci: 'Phalaenopsis fasciata', fullName: 'Phalaenopsis fasciata Rchb.f.', common: '', genus: 'Phalaenopsis', category: 'VU', endemic: false, source: 'DAO 2026-20' },
  { sci: 'Phalaenopsis mariae', fullName: 'Phalaenopsis mariae Burb. ex R.Warner & H.Williams', common: 'Maria moth orchid', genus: 'Phalaenopsis', category: 'VU', endemic: false, source: 'DAO 2026-20' },
  { sci: 'Pinalia curranii', fullName: 'Pinalia curranii (Leav.) W.Suarez & Cootes', common: '', genus: 'Pinalia', category: 'VU', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Renanthera matutina', fullName: 'Renanthera matutina Lindl.', common: '', genus: 'Renanthera', category: 'VU', endemic: true, source: 'DAO 2026-20' },
  { sci: 'Vandopsis lissochiloides', fullName: 'Vandopsis lissochiloides (Gaudich.) Pfitzer', common: '', genus: 'Vandopsis', category: 'VU', endemic: false, source: 'DAO 2026-20' },

  // -- Category D: Other Threatened Species (1) ---------------------------
  { sci: 'Acanthophippium mantinianum', fullName: 'Acanthophippium mantinianum L.Linden & Cogn.', common: 'Mantin acanthophippium', genus: 'Acanthophippium', category: 'OTS', endemic: true, source: 'DAO 2026-20' }
];
