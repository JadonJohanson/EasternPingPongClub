import { Route, Routes } from 'react-router-dom'
import Layout from './components/Layout.jsx'
import Contact from './pages/Contact.jsx'
import Home from './pages/Home.jsx'
import Info from './pages/Info.jsx'
import NotFound from './pages/NotFound.jsx'
import Play from './pages/Play.jsx'
import PlayerProfile from './pages/PlayerProfile.jsx'
import Players from './pages/Players.jsx'
import Results from './pages/Results.jsx'
import Schedule from './pages/Schedule.jsx'
import SignUp from './pages/SignUp.jsx'

// The map of the site: each <Route> says "when the address is X, show page Y".
// Every page is nested inside <Layout>, so they all share the top bar and
// sidebar. `index` means "the page shown at the bare address".
export default function App() {
  return (
    <Routes>
      <Route element={<Layout />}>
        <Route index element={<Home />} />
        <Route path="schedule" element={<Schedule />} />
        <Route path="results" element={<Results />} />
        <Route path="players" element={<Players />} />
        <Route path="players/:playerId" element={<PlayerProfile />} />
        <Route path="play" element={<Play />} />
        <Route path="info" element={<Info />} />
        <Route path="signup" element={<SignUp />} />
        <Route path="contact" element={<Contact />} />
        {/* "*" matches any address not listed above. */}
        <Route path="*" element={<NotFound />} />
      </Route>
    </Routes>
  )
}
